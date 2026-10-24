# Getting started

## Load the system

From the repository root, enter the flake development shell and start SBCL:

```sh
nix develop
sbcl
```

At the SBCL prompt, load the ASDF system:

```lisp
(asdf:load-system "cl-audio-kit")
```

The development shell exposes the source tree through `CL_SOURCE_REGISTRY` and
includes the `cl-weave` test dependency. It also sets
`CL_AUDIO_KIT_PORTAUDIO_LIBRARY` to the Nix store library file when that
variable is unset.

## Select the output device

`open-output-stream` uses the PortAudio default output device when `device` is
`NIL`. Choose the desired system default output device before opening a stream.
The [manual audio check](guide/manual-audio-check.md) explains how an operator
can verify playback.

To use a stream without audio hardware, create a recording device and pass it as `device`. The [API reference](reference/api.md#recording-device) describes reading and clearing captured samples.

## PortAudio lookup

The library first honors `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` when it names a full library-file path. If the variable is unset, the loader uses the platform's normal shared-library search.

Nix consumers that depend on `cl-audio-kit` through cl-nix-forge inherit PortAudio as a native runtime library. The generated executable wrapper adds the library directory to the platform loader path. A custom wrapper can instead set `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` to the full store path, such as `…/lib/libportaudio.so` on Linux or `…/lib/libportaudio.dylib` on macOS.

Inside a consumer `pkgs.stdenv.mkDerivation`, set the full library-file path
in the `makeWrapper` call:

```nix
nativeBuildInputs = [ pkgs.makeWrapper ];

installPhase = ''
  mkdir -p "$out/bin"
  makeWrapper ${pkgs.sbcl}/bin/sbcl "$out/bin/my-audio-app" \
    --set CL_AUDIO_KIT_PORTAUDIO_LIBRARY \
      "${pkgs.portaudio}/lib/${
        if pkgs.stdenv.hostPlatform.isDarwin then "libportaudio.dylib" else "libportaudio.so"
      }"
'';
```

The wrapper forwards arguments to SBCL. Invoke it with the consumer's script,
for example:

```sh
my-audio-app --script ./main.lisp
```

When `cl-audio-kit` is listed in a cl-nix-forge package's
`lispDependencies`, the generated executable wrapper includes its ASDF source
registry entry. For a custom derivation, set `CL_SOURCE_REGISTRY` to a tree
containing the application's `.asd` files and source. For example:

```sh
CL_SOURCE_REGISTRY="/path/to/application//" my-audio-app --script /path/to/application/main.lisp
```

The trailing `//` tells ASDF to search the directory tree recursively. See the
[ASDF source registry manual](https://asdf.common-lisp.dev/asdf/Configurations.html)
for other configuration forms.
