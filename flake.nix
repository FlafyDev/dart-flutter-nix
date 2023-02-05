{
  description = "Tools for compiling Flutter and Dart projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
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
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      packages = {
        inherit (pkgs) pubspec-nix;
      };
      devShell = pkgs.mkShell {
        packages = [
          pkgs.pubspec-nix
        ];
      };
    })
    // {
      overlays = {
        dev = _final: prev: let
          shared = prev.callPackage ./builders/shared {};
        in {
          inherit (shared) generatePubCache;
        };
        default = _final: prev: let
          mkPyScript = prev.callPackage ./utils/mk-py-script.nix {
            python = prev.python310;
          };
        in rec {
          pubspec-nix = prev.callPackage ./pubspec-nix {
            inherit mkPyScript;
          };
          buildFlutterApp = prev.callPackage ./builders/build-flutter-app.nix {};
          buildDartApp = prev.callPackage ./builders/build-dart-app.nix {};
          mkFlutterShell = prev.callPackage ./shells/mk-flutter-shell.nix {
            android-sdk-builder = android.sdk.${prev.system};
            inherit pubspec-nix;
          };
        };
      };
    };
}
