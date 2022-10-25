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

  outputs = { self, flake-utils, nixpkgs, android }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        rec {
          packages = {
            inherit (pkgs) deps2nix;
          };
          devShell = pkgs.mkShell {
            packages = [
              pkgs.deps2nix
            ];
          };
        }) // {
      overlays.default = final: prev:
        let
          mkPyScript = prev.callPackage ./utils/mk-py-script.nix {
            python = prev.python310;
          };
        in
        {
          deps2nix = prev.callPackage ./deps2nix {
            inherit mkPyScript;
          };
          buildFlutterApp = prev.callPackage ./builders/build-flutter-app.nix { };
          mkFlutterShell = prev.callPackage ./shells/mk-flutter-shell.nix {
            android-sdk-builder = android.sdk.${prev.system};
          };
        };
    };
}

