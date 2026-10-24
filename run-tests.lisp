(require "asdf")

(let ((root
       (uiop:pathname-directory-pathname
        (or *load-truename* *load-pathname* (uiop:getcwd)))))
  (asdf:initialize-source-registry
   `(:source-registry (:directory ,root) :inherit-configuration))
  (handler-case (asdf:test-system "cl-audio-kit")
    (error (condition)
      (format *error-output* "~&cl-audio-kit tests failed: ~A~%" condition)
      (finish-output *error-output*)
      (uiop:quit 1))))

(finish-output *standard-output*)

(uiop:quit 0)
