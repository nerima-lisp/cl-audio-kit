(in-package #:cl-audio-kit)

(sb-alien:define-alien-routine ("Pa_Initialize" %pa-initialize) sb-alien:int)

(sb-alien:define-alien-routine ("Pa_Terminate" %pa-terminate) sb-alien:int)

(sb-alien:define-alien-routine ("Pa_OpenDefaultStream" %pa-open-default-stream)
                               sb-alien:int
                               (stream-out (* sb-alien:system-area-pointer))
                               (input-channels sb-alien:int)
                               (output-channels sb-alien:int)
                               (sample-format sb-alien:unsigned-long)
                               (sample-rate sb-alien:double)
                               (frames-per-buffer sb-alien:unsigned-long)
                               (callback sb-alien:system-area-pointer)
                               (user-data sb-alien:system-area-pointer))

(sb-alien:define-alien-routine ("Pa_GetStreamInfo" %pa-get-stream-info)
                               sb-alien:system-area-pointer
                               (stream sb-alien:system-area-pointer))

(sb-alien:define-alien-routine ("Pa_StartStream" %pa-start-stream)
                               sb-alien:int
                               (stream sb-alien:system-area-pointer))

(sb-alien:define-alien-routine ("Pa_WriteStream" %pa-write-stream)
                               sb-alien:int
                               (stream sb-alien:system-area-pointer)
                               (buffer sb-alien:system-area-pointer)
                               (frames sb-alien:unsigned-long))

(sb-alien:define-alien-routine
 ("Pa_GetStreamWriteAvailable" %pa-get-stream-write-available)
 sb-alien:long
 (stream sb-alien:system-area-pointer))

(sb-alien:define-alien-routine ("Pa_StopStream" %pa-stop-stream)
                               sb-alien:int
                               (stream sb-alien:system-area-pointer))

(sb-alien:define-alien-routine ("Pa_CloseStream" %pa-close-stream)
                               sb-alien:int
                               (stream sb-alien:system-area-pointer))

(defmacro %with-portaudio-call (&body body)
  (list* 'sb-int:with-float-traps-masked '(:invalid) body))

(defvar *portaudio-library-loaded-p*
  nil)

(defvar *portaudio-library-path*
  nil)

(defvar *portaudio-initialized-p*
  nil)

(defvar *portaudio-users*
  0)

(defvar *portaudio-lock*
  (sb-thread:make-mutex :name "cl-audio-kit PortAudio"))

(defun %null-sap-p (sap)
  (zerop (sb-sys:sap-int sap)))

(defun %default-portaudio-library-names ()
  (or #+darwin '("libportaudio.2.dylib" "libportaudio.dylib")
      #+linux '("libportaudio.so.2" "libportaudio.so")
      nil))

(defun %load-portaudio-library-locked ()
  (unless *portaudio-library-loaded-p*
    (let* ((override (sb-ext:posix-getenv "CL_AUDIO_KIT_PORTAUDIO_LIBRARY"))
           (candidates
            (if override
                (list override)
                (%default-portaudio-library-names)))
           (last-error nil))
      (dolist (candidate candidates)
        (handler-case (progn
                        (sb-alien:load-shared-object candidate)
                        (setf *portaudio-library-path* candidate)
                        (setf *portaudio-library-loaded-p* t)
                        (return))
          (error (condition)
            (setf last-error condition))))
      (unless *portaudio-library-loaded-p*
        (error 'audio-library-unavailable
               :operation
               "load PortAudio library"
               :detail
               (cond
                 (override
                  (format nil
                          "Could not load CL_AUDIO_KIT_PORTAUDIO_LIBRARY: ~A"
                          last-error))
                 (candidates
                  (format nil
                          "Could not load a supported PortAudio library: ~A"
                          last-error))
                 (t "No PortAudio loader names are defined for this platform."))))))
  *portaudio-library-path*)

(defun check-portaudio-status (operation code)
  (unless (zerop code)
    (let ((condition-type
           (if (member code '(-9996 -9993 -9985))
               'audio-device-unavailable
               'audio-error)))
      (error condition-type
             :operation
             operation
             :code
             code
             :detail
             "PortAudio returned an error code.")))
  code)

(defun %acquire-portaudio ()
  (let ((lock *portaudio-lock*))
    (sb-thread:with-mutex (lock)
                          (%load-portaudio-library-locked)
                          (unless *portaudio-initialized-p*
                            (check-portaudio-status "Pa_Initialize"
                                                    (%with-portaudio-call
                                                     (%pa-initialize)))
                            (setf *portaudio-initialized-p* t))
                          (incf *portaudio-users*)))
  t)

(defun %release-portaudio ()
  (let ((lock *portaudio-lock*))
    (sb-thread:with-mutex (lock)
                          (when (plusp *portaudio-users*)
                            (decf *portaudio-users*)
                            (when (zerop *portaudio-users*)
                              (setf *portaudio-initialized-p* nil)
                              (check-portaudio-status "Pa_Terminate"
                                                      (%with-portaudio-call
                                                       (%pa-terminate)))))))
  nil)

(defun %portaudio-open-default-stream (channels sample-rate
                                                sample-format
                                                frames-per-buffer)
  (sb-alien:with-alien ((stream-out sb-alien:system-area-pointer))
                       (setf stream-out (sb-sys:int-sap 0))
                       (let ((status
                              (%with-portaudio-call
                               (%pa-open-default-stream
                                (sb-alien:addr stream-out)
                                0
                                channels
                                sample-format
                                sample-rate
                                frames-per-buffer
                                (sb-sys:int-sap 0)
                                (sb-sys:int-sap 0)))))
                         (values status stream-out))))

(defun %cleanup-attempt (function)
  (handler-case (progn
                  (funcall function)
                  nil)
    (error (condition)
      condition)))

(defun %cleanup-portaudio-resources (sap started-p opened-p acquired-p)
  (let ((errors nil))
    (when started-p
      (push
       (%cleanup-attempt
        (lambda ()
          (check-portaudio-status "Pa_StopStream"
                                  (%with-portaudio-call (%pa-stop-stream sap)))))
       errors))
    (when opened-p
      (push
       (%cleanup-attempt
        (lambda ()
          (check-portaudio-status "Pa_CloseStream"
                                  (%with-portaudio-call (%pa-close-stream sap)))))
       errors))
    (when acquired-p
      (push (%cleanup-attempt #'%release-portaudio) errors))
    (remove nil (nreverse errors))))

(defun %cleanup-error-detail (primary errors)
  (with-output-to-string (stream)
    (format stream "~A" primary)
    (dolist (condition errors)
      (format stream "; cleanup failed: ~A" condition))))

(defun %signal-cleanup-errors (operation primary errors)
  (error 'audio-error
         :operation
         operation
         :detail
         (%cleanup-error-detail primary errors)))

(defun %open-portaudio-stream (channels sample-rate
                                        sample-format
                                        frames-per-buffer)
  (let ((sap (sb-sys:int-sap 0))
        (opened-p nil)
        (started-p nil)
        (acquired-p nil)
        (latency 0d0))
    (handler-case (progn
                    (%acquire-portaudio)
                    (setf acquired-p t)
                    (multiple-value-bind (status stream)
                        (%portaudio-open-default-stream channels
                                                        sample-rate
                                                        (ecase sample-format
                                                          (:float32 1)
                                                          (:int16 8))
                                                        frames-per-buffer)
                      (setf sap stream)
                      (check-portaudio-status "Pa_OpenDefaultStream" status)
                      (setf opened-p (not (%null-sap-p sap))))
                    (unless opened-p
                      (error 'audio-device-unavailable
                             :operation
                             "Pa_OpenDefaultStream"
                             :detail
                             "PortAudio returned a null output stream."))
                    (let ((info
                           (%with-portaudio-call (%pa-get-stream-info sap))))
                      (when (%null-sap-p info)
                        (error 'audio-error
                               :operation
                               "Pa_GetStreamInfo"
                               :detail
                               "PortAudio returned a null stream-info pointer."))
                      (setf latency (sb-sys:sap-ref-double info 16)))
                    (check-portaudio-status "Pa_StartStream"
                                            (%with-portaudio-call
                                             (%pa-start-stream sap)))
                    (setf started-p t)
                    (values sap latency))
      (error (condition)
        (let ((cleanup-errors
               (%cleanup-portaudio-resources sap started-p opened-p acquired-p)))
          (if cleanup-errors
              (%signal-cleanup-errors "open-output-stream cleanup"
                                      condition
                                      cleanup-errors)
              (error condition)))))))

(defun %write-portaudio-stream (sap samples frames)
  (sb-sys:with-pinned-objects (samples)
                              (check-portaudio-status "Pa_WriteStream"
                                                      (%with-portaudio-call
                                                       (%pa-write-stream sap
                                                                         (sb-sys:vector-sap
                                                                          samples)
                                                                         frames)))))

(defun %portaudio-stream-write-available (sap)
  (let ((available (%with-portaudio-call (%pa-get-stream-write-available sap))))
    (if (minusp available)
        (check-portaudio-status "Pa_GetStreamWriteAvailable" available)
        available)))

(defun %stop-portaudio-stream (sap)
  (check-portaudio-status "Pa_StopStream"
                          (%with-portaudio-call (%pa-stop-stream sap))))

(defun %close-portaudio-stream (sap)
  (check-portaudio-status "Pa_CloseStream"
                          (%with-portaudio-call (%pa-close-stream sap))))
