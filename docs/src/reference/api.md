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
that remains positive and finite when converted to a double float. `channels`
must be a positive integer no greater than 2147483647; PortAudio also checks
that the default output device supports that count. `sample-format` must be
`:float32` or `:int16`. This API does not select hardware devices by name or
index.

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

Calling `abort-output-stream` from another thread attempts to interrupt a
`write-frames` call blocked in PortAudio. PortAudio leaves the thread safety of
this concurrent call unspecified and platform-dependent, so it is not
guaranteed safe on every backend. A host API is PortAudio's platform-specific
audio backend, such as CoreAudio or JACK. For a PortAudio stream opened with
`:device nil`, this library opens PortAudio's default output device. PortAudio
chooses the host API for that device, but this library does not report which one.
An external PortAudio program can inspect it with `Pa_GetDefaultOutputDevice`,
`Pa_GetDeviceInfo`, and `Pa_GetHostApiInfo`. In PortAudio 19.7.0, the CoreAudio
backend interrupts the blocked write, while the JACK backend waits for queued
output to drain before aborting. The PortAudio build supplied by this
repository's Nix flake is 19.7.0, but `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` can load
a different build. This call
does not close the stream; call `close-output-stream` afterward to release its
resources. Writes to an aborted PortAudio stream signal `audio-error`.
Further calls to `abort-output-stream` after a successful abort have no effect.
Calling it on a closed stream also has no effect. Recording streams are
unaffected and remain writable.

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
a recording stream.

### Conditions

Opening the default PortAudio device signals `audio-device-unavailable` for
PortAudio's invalid-device, bad-I/O-combination, or device-unavailable errors.
If the PortAudio shared library cannot be loaded, opening a hardware stream
signals `audio-library-unavailable`. Other PortAudio failures signal
`audio-error`. `write-frames` and
`stream-write-available` signal `audio-error` when used after the stream is
closed. Passing a value that is not an `output-stream` to a stream operation or
not a `recording-device` to a recording-device operation signals `type-error`.
Invalid types or ranges for sample-rate, channel-count, sample-format, sample
vector, or the `device` argument also signal `type-error`. A sample count that
does not form whole frames or an invalid `frames-per-buffer` value signals
`simple-error`.

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
