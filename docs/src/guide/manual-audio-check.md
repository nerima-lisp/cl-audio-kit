# Manual audio check

## Before running

1. From the repository root, use your operating system's sound settings to select the output device you intend to test.
2. Confirm that the selected device is connected and that its volume is audible.
3. Run the check below from the repository root. `device` is omitted, so the library opens PortAudio's default output device.

```sh
nix develop --command sbcl --script /dev/stdin <<'LISP'
(require :asdf)
(asdf:load-system "cl-audio-kit")

(let ((samples (make-array 48000 :element-type 'single-float)))
  (dotimes (frame (length samples))
    (setf (aref samples frame)
          (coerce (* 0.2d0
                     (sin (* 2d0 pi 440d0 (/ frame 48000d0))))
                  'single-float)))
  (cl-audio-kit:with-output-stream
      (stream :sample-rate 48000.0d0 :channels 1 :sample-format :float32)
    (let ((frames (cl-audio-kit:write-frames stream samples)))
      (unless (= frames 48000)
        (error "Expected 48000 frames, wrote ~D" frames))
      (format t "Wrote ~D frames; output latency ~,3F seconds.~%"
              frames
              (cl-audio-kit:stream-latency stream)))))
LISP
```

The command writes 48,000 mono float32 frames at 48 kHz, a one-second 440 Hz
tone. Check that SBCL reports 48,000 frames, then listen for the tone on the
selected device.

The returned frame count shows that the blocking write completed, and the
latency value reports the stream's output latency in seconds. Neither confirms
that sound reached the selected output. An operator must listen and confirm
the tone manually.

If the command cannot load PortAudio, check that `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` is unset or names a full library file. The flake shell supplies its pinned Nix store path by default.

To exercise the in-memory write path without audio hardware, create a
recording device, pass it as `:device`, then check the captured sample count
and first value:

```sh
nix develop --command sbcl --script /dev/stdin <<'LISP'
(require :asdf)
(asdf:load-system "cl-audio-kit")

(let ((device (cl-audio-kit:make-recording-device))
      (samples (make-array 48000 :element-type 'single-float :initial-element 0.25)))
  (cl-audio-kit:with-output-stream
      (stream :device device :sample-rate 48000d0 :channels 1 :sample-format :float32)
    (cl-audio-kit:write-frames stream samples))
  (let ((captured (first (cl-audio-kit:recorded-samples device))))
    (unless (= (length captured) 48000)
      (error "Expected 48000 captured samples, got ~D" (length captured)))
    (unless (= (aref captured 0) 0.25)
      (error "Expected first sample to be 0.25, got ~A" (aref captured 0)))
    (format t "Captured ~D samples; first value is ~A.~%"
            (length captured)
            (aref captured 0))))
LISP
```
