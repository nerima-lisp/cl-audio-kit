# API reference

Load the ASDF system `cl-audio-kit` before using these functions and macros.
The examples use the `cl-audio-kit` package; from `CL-USER`, qualify names
with `cl-audio-kit:` or switch packages with `(in-package #:cl-audio-kit)`.

## Output stream

### `open-output-stream`

```lisp
(open-output-stream
  &key
    (sample-rate 48000.0d0)
    (channels 1)
    (sample-format :float32)
    (frames-per-buffer 0)
    device)
```

Opens a blocking output stream. A `NIL` device uses PortAudio's default
output device. Pass a recording device from `make-recording-device` to capture
writes in memory instead of opening audio hardware. `frames-per-buffer` is
passed to PortAudio; it must be a non-negative fixnum, and zero leaves the
buffer size unspecified. `sample-rate` must be a positive finite real value
that converts to a finite double float. `channels` must be a positive integer;
PortAudio also checks that the default output device supports that count.
`sample-format` must be `:float32` or `:int16`. To choose a physical output,
select it as the operating system's default before opening the stream; this
API does not select devices by name or index.

### `write-frames`

```lisp
(write-frames stream samples)
```

Writes a simple one-dimensional sample vector and returns the number of
frames written. `:float32` requires
`(simple-array single-float (*))`; `:int16` requires
`(simple-array (signed-byte 16) (*))`. Adjustable or displaced vectors are
not accepted. For multiple channels, samples are interleaved by frame: the
first `channels` elements form one frame. The vector length must be divisible
by the stream's channel count.

### `abort-output-stream`

```lisp
(abort-output-stream stream)
```

Requests immediate termination of a PortAudio stream. Call this from another
thread to interrupt a `write-frames` call that is blocked in PortAudio. It does
not close the stream; call `close-output-stream` afterward to release its
resources. Writes to an aborted PortAudio stream signal `audio-error`.
Recording streams are unaffected and remain writable. PortAudio errors signal
`audio-error`.

### `close-output-stream`

```lisp
(close-output-stream stream)
```

Closes an output stream. Closing an already closed stream has no effect.

### `with-output-stream`

```lisp
(with-output-stream (stream &rest open-keywords)
  &body body)
```

Opens a stream using `open-keywords`, binds it to `stream`, evaluates `body`, and closes the stream when the body exits.

### `stream-latency`

```lisp
(stream-latency stream)
```

Returns output latency in seconds. A recording stream reports zero.

### `stream-write-available`

```lisp
(stream-write-available stream)
```

Returns the number of frames that can be written without waiting, or `NIL` for
a recording stream. Signals `audio-error` if PortAudio reports an error.

### Conditions

Opening the default PortAudio device signals `audio-device-unavailable` for
PortAudio's invalid-device, bad-I/O-combination, or device-unavailable errors.
If the PortAudio shared library cannot be loaded, opening a hardware stream
signals `audio-library-unavailable`. Other PortAudio failures signal
`audio-error`. `write-frames` and
`stream-write-available` signal `audio-error` when used after the stream is
closed. Invalid sample-rate, channel-count, sample-format, sample-vector, or
device types and ranges signal `type-error`. A sample count that does not form
whole frames or an invalid `frames-per-buffer` value signals `simple-error`.

## Recording device

### `make-recording-device`

```lisp
(make-recording-device)
```

Creates an in-memory recording device for use as the `device` argument to `open-output-stream`.

### `recorded-samples`

```lisp
(recorded-samples device)
```

Returns copied sample vectors in `write-frames` call order. Each vector
corresponds to one write call and retains that call's sample format.

### `clear-recording-device`

```lisp
(clear-recording-device device)
```

Clears the samples captured by a recording device.

## PortAudio library lookup

Set `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` to a full shared-library file path to
override the default loader search. For example, a custom Nix wrapper can set
it to the `libportaudio.so` file on Linux or the `libportaudio.dylib` file on
macOS. When set, the loader tries only that path; if it cannot load the file,
opening a hardware stream signals `audio-library-unavailable` without trying
the platform search names.
