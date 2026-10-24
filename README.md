# cl-audio-kit

[![CI](https://github.com/nerima-lisp/cl-audio-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/nerima-lisp/cl-audio-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-blue)](https://nerima-lisp.github.io/cl-audio-kit/)

Blocking PortAudio output for Common Lisp.

## Quick Start

Enter the Nix development shell, then load the ASDF system in SBCL:

```sh
nix develop
sbcl
```

```lisp
(asdf:load-system "cl-audio-kit")
```

The shell adds the project to the ASDF registry and points the PortAudio loader override at the Nix store library when no override is already set.

## Install

Add the release as an input and include its package in the dependency list
passed to `cl-nix-forge.lib.<system>.mkPackageFlake`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cl-nix-forge.url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
    cl-nix-forge.inputs.nixpkgs.follows = "nixpkgs";
    cl-audio-kit.url = "github:nerima-lisp/cl-audio-kit/v0.1.0";
    cl-audio-kit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, cl-nix-forge, cl-audio-kit, ... }:
    let systems = [ "aarch64-darwin" "x86_64-linux" ]; in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit self nixpkgs systems;
      pname = "my-audio-app";
      asd = ./my-audio-app.asd;
      root = ./.;
      lispDependencies = ctx: [
        cl-audio-kit.packages.${ctx.system}.cl-audio-kit
      ];
    };
}
```

cl-nix-forge propagates the PortAudio runtime dependency to consumer executables and adds its library directory to the executable wrapper. For a custom wrapper that launches SBCL directly, set `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` to the full PortAudio library file path.

Outside Nix, install PortAudio and make its shared library available to the system loader, or set `CL_AUDIO_KIT_PORTAUDIO_LIBRARY` to the full library-file path.

## Documentation

Start with [getting started](docs/src/getting-started.md), see the [API reference](docs/src/reference/api.md), or follow the [manual audio check](docs/src/guide/manual-audio-check.md).

## Development

Use `nix develop` for an SBCL shell with the project and test dependencies available. Run `nix run .#test` for the test suite or `nix flake check` for tests, formatting, and strict documentation checks.

## Contributing

Bug reports and pull requests are welcome. Open an issue first for changes that affect the public API.

## Support

Report problems in the [GitHub issue tracker](https://github.com/nerima-lisp/cl-audio-kit/issues).

