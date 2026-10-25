(defpackage #:cl-audio-kit
  (:use #:cl)
  (:export
   #:audio-error
   #:audio-device-unavailable
   #:audio-library-unavailable
   #:open-output-stream
   #:write-frames
   #:abort-output-stream
   #:close-output-stream
   #:with-output-stream
   #:stream-latency
   #:stream-write-available
   #:make-recording-device
   #:recorded-samples
   #:clear-recording-device))

