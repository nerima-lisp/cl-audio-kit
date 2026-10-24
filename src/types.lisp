(in-package #:cl-audio-kit)

(defstruct (recording-device (:constructor %make-recording-device))
  (chunks nil)
  (lock (sb-thread:make-mutex :name "cl-audio-kit recording device")))

(defstruct
    (output-stream (:constructor %make-output-stream)
                   (:predicate %output-stream-p))
  backend
  sample-rate
  channels
  sample-format
  frames-per-buffer
  recording-device
  (foreign-stream (sb-sys:int-sap 0))
  (latency 0d0)
  (started-p nil)
  (runtime-acquired-p nil)
  (closed-p nil)
  (lock (sb-thread:make-mutex :name "cl-audio-kit output stream")))
