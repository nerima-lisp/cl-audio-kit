(in-package #:cl-audio-kit/test)

(defun %float32-vector (&rest contents)
  (make-array (length contents)
              :element-type
              'single-float
              :initial-contents
              contents))

(defun %int16-vector (&rest contents)
  (make-array (length contents)
              :element-type
              '(signed-byte 16)
              :initial-contents
              contents))

(defun %signals-condition-p (condition-type thunk)
  (handler-case (progn
                  (funcall thunk)
                  nil)
    (error (condition)
      (typep condition condition-type))))

(defun %signals-exact-condition-p (condition-type thunk)
  (handler-case (progn
                  (funcall thunk)
                  nil)
    (error (condition)
      (eq (type-of condition) condition-type))))

(describe "recording output streams"
          (it "records copied float32 vectors and reports frame counts"
              (let* ((device (make-recording-device))
                     (samples (%float32-vector 0.25s0 -0.5s0 0.75s0 -1.0s0))
                     (expected (copy-seq samples))
                     (stream (open-output-stream :device device :channels 2)))
                (unwind-protect
                    (progn
                      (expect (stream-latency stream) :to-be 0.0d0)
                      (expect (stream-write-available stream) :to-be nil)
                      (expect (write-frames stream samples) :to-be 2)
                      (setf (aref samples 0) 1.0s0)
                      (let ((recorded (first (recorded-samples device))))
                        (expect
                         (typep recorded '(simple-array single-float (*)))
                         :to-be
                         t)
                        (expect recorded :to-equalp expected)
                        (setf (aref recorded 1) 1.0s0)
                        (expect (recorded-samples device)
                                :to-equalp
                                (list expected)))
                      (expect (recorded-samples device)
                              :to-equalp
                              (list expected)))
                  (close-output-stream stream))))
          (it "records int16 vectors with their specialized element type"
              (let* ((device (make-recording-device))
                     (samples (%int16-vector -32768 -1 0 32767))
                     (expected (copy-seq samples))
                     (stream
                      (open-output-stream :device
                                          device
                                          :channels
                                          2
                                          :sample-format
                                          :int16)))
                (unwind-protect
                    (progn
                      (expect (write-frames stream samples) :to-be 2)
                      (expect (recorded-samples device)
                              :to-equalp
                              (list expected))
                      (expect
                       (typep (first (recorded-samples device))
                              '(simple-array (signed-byte 16) (*)))
                       :to-be
                       t))
                  (close-output-stream stream))))
          (it "preserves multiple writes in order and returns each frame count"
              (let* ((device (make-recording-device))
                     (first-write (%float32-vector 0.1s0 -0.1s0))
                     (second-write (%float32-vector 0.2s0 -0.2s0 0.3s0 -0.3s0))
                     (expected-first (copy-seq first-write))
                     (expected-second (copy-seq second-write))
                     (stream (open-output-stream :device device :channels 2)))
                (unwind-protect
                    (progn
                      (expect (write-frames stream first-write) :to-be 1)
                      (expect (write-frames stream second-write) :to-be 2)
                      (expect (recorded-samples device)
                              :to-equalp
                              (list expected-first expected-second)))
                  (close-output-stream stream))))
          (it "allows repeated close calls"
              (let* ((device (make-recording-device))
                     (stream (open-output-stream :device device)))
                (close-output-stream stream)
                (close-output-stream stream)))
          (it "closes the stream when the body exits nonlocally"
              (let ((device (make-recording-device))
                    (opened-stream nil)
                    (closed-stream nil)
                    (close-count 0))
                (flet ((close-output-stream (stream)
                         (setf closed-stream stream)
                         (incf close-count)))
                  (expect
                   (catch 'finished
                     (with-output-stream (opened :device device)
                                         (setf opened-stream opened)
                                         (write-frames opened
                                                       (%float32-vector 0.5s0))
                                         (throw 'finished
                                           :finished)))
                   :to-be
                   :finished)
                  (expect close-count :to-be 1)
                  (expect (eq closed-stream opened-stream) :to-be t)
                  (expect (recorded-samples device)
                          :to-equalp
                          (list (%float32-vector 0.5s0)))))))

(describe "recording stream validation"
          (it "rejects invalid stream parameter types and values"
              (let ((device (make-recording-device)))
                (expect
                 (%signals-condition-p 'type-error
                                       (lambda ()
                                         (open-output-stream :device
                                                             device
                                                             :sample-rate
                                                             "48000")))
                 :to-be
                 t)
                (expect
                 (%signals-condition-p 'type-error
                                       (lambda ()
                                         (open-output-stream :device
                                                             device
                                                             :sample-rate
                                                             0.0d0)))
                 :to-be
                 t)
                (expect
                 (%signals-condition-p 'type-error
                                       (lambda ()
                                         (open-output-stream :device
                                                             device
                                                             :channels
                                                             1.5)))
                 :to-be
                 t)
                (expect
                 (%signals-condition-p 'type-error
                                       (lambda ()
                                         (open-output-stream :device
                                                             device
                                                             :channels
                                                             0)))
                 :to-be
                 t)
                (expect
                 (%signals-condition-p 'type-error
                                       (lambda ()
                                         (open-output-stream :device
                                                             device
                                                             :sample-format
                                                             :int32)))
                 :to-be
                 t)
                (expect
                 (%signals-exact-condition-p 'simple-error
                                             (lambda ()
                                               (open-output-stream :device
                                                                   device
                                                                   :frames-per-buffer
                                                                   -1)))
                 :to-be
                 t)))
          (it "rejects a vector with the wrong specialized sample format"
              (let* ((device (make-recording-device))
                     (stream (open-output-stream :device device)))
                (unwind-protect
                    (expect
                     (%signals-condition-p 'type-error
                                           (lambda ()
                                             (write-frames stream
                                                           (%int16-vector 1 2))))
                     :to-be
                     t)
                  (close-output-stream stream))))
          (it
           "rejects sample counts that are not divisible by the channel count"
           (let* ((device (make-recording-device))
                  (stream (open-output-stream :device device :channels 2)))
             (unwind-protect
                 (expect
                  (%signals-exact-condition-p 'simple-error
                                              (lambda ()
                                                (write-frames stream
                                                              (%float32-vector
                                                               0.1s0
                                                               0.2s0
                                                               0.3s0))))
                  :to-be
                  t)
               (close-output-stream stream))))
          (it "maps PortAudio status codes to the documented condition types"
              (expect (cl-audio-kit::check-portaudio-status "probe" 0) :to-be 0)
              (dolist (code '(-9996 -9985))
                (expect
                 (%signals-condition-p 'audio-device-unavailable
                                       (lambda ()
                                         (cl-audio-kit::check-portaudio-status
                                          "probe"
                                          code)))
                 :to-be
                 t))
              (expect
               (%signals-exact-condition-p 'audio-error
                                           (lambda ()
                                             (cl-audio-kit::check-portaudio-status
                                              "probe"
                                              -10000)))
               :to-be
               t)))
