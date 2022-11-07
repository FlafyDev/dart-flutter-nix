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
        inherit (pkgs) deps2nix;
      };
      devShell = pkgs.mkShell {
        packages = [
          pkgs.deps2nix
        ];
      };
    })
    // {
      overlays.default = _final: prev: let
        mkPyScript = prev.callPackage ./utils/mk-py-script.nix {
          python = prev.python310;
        };
        shared = prev.callPackage ./builders/shared {};
      in {
        deps2nix = prev.callPackage ./deps2nix {
          inherit mkPyScript;
        };
        inherit (shared) generatePubCache;
        buildFlutterApp = prev.callPackage ./builders/build-flutter-app.nix {};
        buildDartApp = prev.callPackage ./builders/build-dart-app.nix {};
        mkFlutterShell = prev.callPackage ./shells/mk-flutter-shell.nix {
          android-sdk-builder = android.sdk.${prev.system};
        };
      };
    };
}
