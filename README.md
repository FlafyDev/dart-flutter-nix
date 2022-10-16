# dart-flutter-nix

Tools for compiling Flutter and Dart projects with Nix

## Examples
[github:FlafyDev/guifetch](https://github.com/FlafyDev/guifetch)

## Packaging a Flutter project
1. run `deps2nix`
deps2nix should be built with your version of Flutter as a dependency (It can't take from path because it needs `flutter.unwrapped`).
```nix
system: let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ dart-flutter.overlays.default ];
  }; 
in {
  devShell = pkgs.mkShell {
    packages = [
      pkgs.deps2nix
    ];
  };
}
```

Once you have `deps2nix`, run it at the root of your Flutter project and wait for it to download everything.
After `deps2nix` finishing, a file named `deps2nix.lock` should be created at the root of your Flutter project.

2. Making a derivation with `buildFlutterApp`
Now that you have the `deps2nix.lock`. All that's left is to make a package with `buildFlutterApp`:
```nix
{ buildFlutterApp }:

buildFlutterApp {
  pname = "pname";
  version = "version";

  src = ./.;
}
```
`depsFile` can be set to override the default location of `deps2nix.lock` (the root of the Flutter project.)
Setting `configurePhase`, `buildPhase`, and `installPhase` will do nothing. Consider using `pre` and `post` instead.


## Packaging a Dart project
Planned

## Development enviroments
Planned
