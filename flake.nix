{
  description = "Tools for compiling Flutter and Dart projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        rec {
          packages =
            let
              mkPyScript = pkgs.callPackage ./utils/mk-py-script.nix {
                python = pkgs.python310;
              };
            in
            {
              deps2nix = pkgs.callPackage ./deps2nix {
                inherit mkPyScript;
              };
            };
          devShell = pkgs.mkShell {
            packages = [
              packages.deps2nix
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
          buildFlutterApp = prev.callPackage ./build-flutter-app.nix { };
        };
    };
}

