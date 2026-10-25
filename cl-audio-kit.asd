(asdf:defsystem "cl-audio-kit"
  :description "Common Lisp audio output through PortAudio"
  :version "0.1.1"
  :license "MIT"
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "conditions")
     (:file "types")
     (:file "recording")
     (:file "portaudio")
     (:file "stream"))))
  :in-order-to
  ((asdf:test-op (asdf:test-op "cl-audio-kit/test"))))
(asdf:defsystem "cl-audio-kit/test"
  :depends-on ("cl-audio-kit" "cl-weave")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:file "package")
     (:file "cl-audio-kit-test"))))
  :perform (asdf:test-op (operation system)
    (declare (ignore operation system))
    (uiop:symbol-call :cl-audio-kit/test :run-tests)))
