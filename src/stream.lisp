(in-package #:cl-audio-kit)

(defun %positive-finite-rate-p (rate)
  (and (realp rate)
       (or (not (floatp rate))
           (and (not (sb-ext:float-nan-p rate))
                (not (sb-ext:float-infinity-p rate))))
       (> rate 0)))

(deftype positive-finite-sample-rate ()
  '(and real (satisfies %positive-finite-rate-p)))

(defun %validated-sample-rate (sample-rate)
  (unless (%positive-finite-rate-p sample-rate)
    (error 'type-error
           :datum
           sample-rate
           :expected-type
           'positive-finite-sample-rate))
  (let ((rate
         (handler-case (float sample-rate 1d0)
           (arithmetic-error ()
             nil))))
    (unless
        (and rate
             (plusp rate)
             (not (sb-ext:float-nan-p rate))
             (not (sb-ext:float-infinity-p rate)))
      (error 'type-error
             :datum
             sample-rate
             :expected-type
             'positive-finite-sample-rate))
    rate))

(defun %validated-channels (channels)
  (unless (and (integerp channels) (<= 1 channels #x7fffffff))
    (error 'type-error :datum channels :expected-type '(integer 1 #x7fffffff)))
  channels)

(defun %validated-sample-format (sample-format)
  (unless (member sample-format '(:float32 :int16))
    (error 'type-error
           :datum
           sample-format
           :expected-type
           '(member :float32 :int16)))
  sample-format)

(defun %validated-frames-per-buffer (frames-per-buffer)
  (unless
      (and (integerp frames-per-buffer)
           (<= 0 frames-per-buffer most-positive-fixnum))
    (error "frames-per-buffer must be a non-negative fixnum: ~S"
           frames-per-buffer))
  frames-per-buffer)

(defun %validated-device (device)
  (unless (or (null device) (recording-device-p device))
    (error 'type-error
           :datum
           (type-of device)
           :expected-type
           '(or null recording-device)))
  device)

(defun %validate-samples (samples sample-format channels)
  (let* ((expected-vector-type
          (ecase sample-format
            (:float32 '(simple-array single-float (*)))
            (:int16 '(simple-array (signed-byte 16) (*)))))
         (expected-element-type
          (ecase sample-format
            (:float32 'single-float)
            (:int16 '(signed-byte 16)))))
    (unless (typep samples expected-vector-type)
      (error 'type-error
             :datum
             (array-element-type samples)
             :expected-type
             expected-element-type))
    (let ((sample-count (length samples)))
      (unless (zerop (mod sample-count channels))
        (error "sample count ~D is not divisible by channel count ~D"
               sample-count
               channels))
      (/ sample-count channels))))

(defun %require-open-stream (stream)
  (when (output-stream-closed-p stream)
    (error 'audio-error
           :operation
           "output stream"
           :detail
           "The output stream is closed."))
  stream)

(defun open-output-stream (&key (sample-rate 48000.0d0)
                                (channels 1)
                                (sample-format :float32)
                                (frames-per-buffer 0)
                                device)
  (let* ((rate (%validated-sample-rate sample-rate))
         (channels (%validated-channels channels))
         (format (%validated-sample-format sample-format))
         (frames-per-buffer (%validated-frames-per-buffer frames-per-buffer))
         (device (%validated-device device)))
    (if device
        (%make-output-stream :backend
                             :recording
                             :sample-rate
                             rate
                             :channels
                             channels
                             :sample-format
                             format
                             :frames-per-buffer
                             frames-per-buffer
                             :recording-device
                             device
                             :latency
                             0d0)
        (let ((stream
               (%make-output-stream :backend
                                    :portaudio
                                    :sample-rate
                                    rate
                                    :channels
                                    channels
                                    :sample-format
                                    format
                                    :frames-per-buffer
                                    frames-per-buffer)))
          (multiple-value-bind (sap latency)
              (%open-portaudio-stream channels rate format frames-per-buffer)
            (setf (output-stream-foreign-stream stream) sap
                  (output-stream-latency stream) latency
                  (output-stream-started-p stream) t
                  (output-stream-runtime-acquired-p stream) t)
            stream)))))

(defun write-frames (stream samples)
  (unless (%output-stream-p stream)
    (error 'type-error :datum (type-of stream) :expected-type 'output-stream))
  (let* ((frames
          (%validate-samples samples
                             (output-stream-sample-format stream)
                             (output-stream-channels stream)))
         (lock (output-stream-lock stream)))
    (sb-thread:with-mutex (lock)
                          (%require-open-stream stream)
                          (ecase (output-stream-backend stream)
                            (:recording
                              (%append-recorded-samples
                               (output-stream-recording-device stream)
                               samples)
                              frames)
                            (:portaudio
                              (unless (zerop frames)
                                (%write-portaudio-stream
                                 (output-stream-foreign-stream stream)
                                 samples
                                 frames))
                              frames)))))

(defun close-output-stream (stream)
  (unless (%output-stream-p stream)
    (error 'type-error :datum (type-of stream) :expected-type 'output-stream))
  (let ((lock (output-stream-lock stream)))
    (sb-thread:with-mutex (lock)
                          (unless (output-stream-closed-p stream)
                            (let ((errors nil))
                              (when
                                  (eq (output-stream-backend stream) :portaudio)
                                (when (output-stream-started-p stream)
                                  (push
                                   (%cleanup-attempt
                                    (lambda ()
                                      (%stop-portaudio-stream
                                       (output-stream-foreign-stream stream))))
                                   errors)
                                  (setf (output-stream-started-p stream) nil))
                                (unless
                                    (%null-sap-p
                                     (output-stream-foreign-stream stream))
                                  (push
                                   (%cleanup-attempt
                                    (lambda ()
                                      (%close-portaudio-stream
                                       (output-stream-foreign-stream stream))))
                                   errors)
                                  (setf (output-stream-foreign-stream stream) (sb-sys:int-sap
                                                                               0)))
                                (when (output-stream-runtime-acquired-p stream)
                                  (push (%cleanup-attempt #'%release-portaudio)
                                        errors)
                                  (setf (output-stream-runtime-acquired-p
                                         stream) nil)))
                              (setf (output-stream-closed-p stream) t)
                              (let ((errors (remove nil (nreverse errors))))
                                (when errors
                                  (%signal-cleanup-errors "close-output-stream"
                                                          "PortAudio stream cleanup failed."
                                                          errors))))))
    stream))

(defun stream-latency (stream)
  (unless (%output-stream-p stream)
    (error 'type-error :datum (type-of stream) :expected-type 'output-stream))
  (output-stream-latency stream))

(defun stream-write-available (stream)
  (unless (%output-stream-p stream)
    (error 'type-error :datum (type-of stream) :expected-type 'output-stream))
  (let ((lock (output-stream-lock stream)))
    (sb-thread:with-mutex (lock)
                          (%require-open-stream stream)
                          (case (output-stream-backend stream)
                            (:recording nil)
                            (:portaudio
                             (%portaudio-stream-write-available
                              (output-stream-foreign-stream stream)))
                            (t
                             (error 'audio-error
                                    :operation
                                    "stream-write-available"
                                    :detail
                                    "The output stream has an unknown backend."))))))

(defmacro with-output-stream ((variable &rest open-keywords) &body body)
  (let ((stream (gensym "STREAM-")))
    (list 'let
          (list (list stream (cons 'open-output-stream open-keywords)))
          (list 'let
                (list (list variable stream))
                (list 'unwind-protect
                      (cons 'progn body)
                      (list 'close-output-stream stream))))))
