{
  description = "Blocking PortAudio output for Common Lisp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      treefmt-nix,
    }:
    let
      # Both platforms have CI coverage: Linux is the release baseline, and
      # aarch64-darwin covers the arm64 development and audio device target.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
    in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit self systems nixpkgs;

      pname = "cl-audio-kit";
      asd = ./cl-audio-kit.asd;
      root = ./.;

      meta = {
        description = "Blocking PortAudio output for Common Lisp";
        homepage = "https://github.com/nerima-lisp/cl-audio-kit";
        license = nixpkgs.lib.licenses.mit;
        platforms = nixpkgs.lib.platforms.unix;
      };

      # cl-weave is used by the test system only, so it does not enter the
      # library package's runtime closure.
      lispCheckDependencies = ctx: [
        cl-weave.packages.${ctx.system}.cl-weave
      ];

      # The native library is propagated through cl-nix-forge Lisp
      # dependencies and added to the runtime search path of consumer
      # executables.
      packageArgs = ctx: {
        nativeLibraries = [ ctx.pkgs.portaudio ];
      };

      # Keep the dev shell's generated ASDF registry and test dependencies.
      # The public loader override takes a full library-file path, so point it
      # at the Nix package only when the caller has not already selected one.
      overrideOutputs =
        ctx:
        let
          portaudioLibrary = "${ctx.pkgs.portaudio}/lib/${
            if ctx.pkgs.stdenv.hostPlatform.isDarwin then "libportaudio.dylib" else "libportaudio.so"
          }";
        in
        {
          devShells.default = ctx.generated.devShells.default.overrideAttrs (old: {
            shellHook = (old.shellHook or "") + ''
              if [ -z "''${CL_AUDIO_KIT_PORTAUDIO_LIBRARY:-}" ]; then
                export CL_AUDIO_KIT_PORTAUDIO_LIBRARY="${portaudioLibrary}"
              fi
            '';
          });
        };

      docs.root = ./docs;
      treefmt.evalModule = treefmt-nix.lib.evalModule;
    };
}
