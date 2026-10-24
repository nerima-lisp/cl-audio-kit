(defpackage #:cl-audio-kit/test
            (:use #:cl #:cl-audio-kit)
            (:shadowing-import-from #:cl-weave #:describe)
            (:import-from #:cl-weave #:expect #:it)
            (:export #:run-tests))

(in-package #:cl-audio-kit/test)

(defun run-tests ()
  (cl-weave:run-all :reporter :spec :pass-with-no-tests nil))
