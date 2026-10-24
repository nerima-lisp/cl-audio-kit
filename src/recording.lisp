(in-package #:cl-audio-kit)

(defun %require-recording-device (device)
  (unless (recording-device-p device)
    (error 'type-error :datum device :expected-type 'recording-device))
  device)

(defun %copy-sample-vector (samples)
  (let ((copy
         (make-array (length samples)
                     :element-type
                     (array-element-type samples))))
    (replace copy samples)
    copy))

(defun make-recording-device ()
  (%make-recording-device))

(defun recorded-samples (device)
  (let* ((device (%require-recording-device device))
         (lock (recording-device-lock device)))
    (sb-thread:with-mutex (lock)
                          (loop for samples in (reverse
                                                (copy-list
                                                 (recording-device-chunks
                                                  device)))
                                collect (%copy-sample-vector samples)))))

(defun clear-recording-device (device)
  (let* ((device (%require-recording-device device))
         (lock (recording-device-lock device)))
    (sb-thread:with-mutex (lock)
                          (setf (recording-device-chunks device) nil))
    device))

(defun %append-recorded-samples (device samples)
  (let ((copy (%copy-sample-vector samples))
        (lock (recording-device-lock device)))
    (sb-thread:with-mutex (lock) (push copy (recording-device-chunks device)))
    (length samples)))
