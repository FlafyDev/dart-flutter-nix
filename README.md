# dart-flutter-nix

Tools for compiling Flutter and Dart projects with Nix

## Examples
[github:FlafyDev/guifetch](https://github.com/FlafyDev/guifetch) - Flutter project  
[github:FlafyDev/listen_blue](https://github.com/FlafyDev/listen_blue) - Flutter project  

## Packaging a Flutter project
###### Tested versions: Flutter v3.0.4, v3.3.3
### 1. run `deps2nix`
deps2nix has to be built with your version of Flutter as a dependency (It can't take `flutter` from path as it requires `flutter.unwrapped`).
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
      # or explicitly match your version of Flutter
      (pkgs.deps2nix.override {
        flutter = pkgs.flutter2;
      })
    ];
  };
}
```

Once you have `deps2nix`, run it at the root of your Flutter project and wait for it to download everything.  
After `deps2nix` is done, a file named `deps2nix.lock` will be created at the root of your Flutter project.

### 2. Making a derivation with `buildFlutterApp`
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
Setting `configurePhase`, `buildPhase`, or `installPhase` will do nothing. Consider using `pre` and `post` instead.

##### To explicitly state which Flutter to use.
```nix
pkgs.callPackage ./package.nix {
  buildFlutterApp = pkgs.buildFlutterApp.override {
    flutter = pkgs.flutter2;
  };
}
```


## Packaging a Dart project
Planned

## Development enviroments
Planned
