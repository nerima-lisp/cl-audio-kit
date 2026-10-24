(in-package #:cl-audio-kit)

(define-condition audio-error
  (error)
  ((operation :initarg :operation :reader audio-error-operation)
   (code :initarg :code :initform nil :reader audio-error-code)
   (detail :initarg :detail :initform nil :reader audio-error-detail))
  (:report
   (lambda (condition stream)
     (format stream "~A" (audio-error-operation condition))
     (when (audio-error-code condition)
       (format stream
               " failed with PortAudio error ~D"
               (audio-error-code condition)))
     (when (audio-error-detail condition)
       (format stream ": ~A" (audio-error-detail condition))))))

(define-condition audio-device-unavailable
  (audio-error)
  ())

(define-condition audio-library-unavailable
  (audio-error)
  ())
