{
  description = "Tools for compiling Flutter and Dart projects";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    android = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    android,
  }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
    ]
    (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      packages = {
        inherit (pkgs) pubspec-nix flutter-elinux flutter;
      };
      checks = {
        inherit (pkgs) pubspec-nix flutter-elinux flutter;
        build-dart-script = pkgs.callPackage ./checks/check-build-dart-script.nix {};
        default-flutter-build = pkgs.callPackage ./checks/default-flutter-build {};
      };
      devShells = rec {
        default = linux-shell;
        linux-shell = pkgs.mkFlutterShell {
          linux.enable = true;
        };
        elinux-shell = pkgs.mkFlutterShell {
          linux.enable = true;
          elinux.enable = true;
        };
        android-shell = pkgs.mkFlutterShell {
          linux.enable = true;
          android = {
            enable = true;
            sdkPackages = sdkPkgs:
              with sdkPkgs; [
                build-tools-30-0-3
                platforms-android-31
              ];
          };
        };
      };
    })
    // {
      overlays = {
        dev = _final: prev: let
          shared = prev.callPackage ./builders/shared {};
        in {
          inherit (shared) generatePubCache;
        };
        default = final: prev: let
          shared = prev.callPackage ./builders/shared {};
          mkPyScript = prev.callPackage ./utils/mk-py-script.nix {
            python = prev.python310;
          };
          unpackTarball = prev.callPackage ./utils/unpack-tarball.nix {};
        in {
          flutter = (prev.callPackage ./flutter {}).stable;
          flutter-elinux = prev.callPackage ./elinux/package.nix {
            inherit unpackTarball;
          };
          pubspec-nix = prev.callPackage ./pubspec-nix {
            inherit mkPyScript;
          };
          buildFlutterApp = prev.callPackage ./builders/build-flutter-app.nix {
            inherit (shared) generatePubCache;
          };
          buildDartApp = prev.callPackage ./builders/build-dart-app.nix {
            inherit (shared) generatePubCache;
          };
          buildDartScript = prev.callPackage ./utils/build-dart-script.nix { };
          mkFlutterShell = prev.callPackage ./shells/mk-flutter-shell.nix {
            android-sdk-builder = android.sdk.${final.system};
          };
        };
      };
    };
}
