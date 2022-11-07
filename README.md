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

  # Opitonal: 
  # depsFile = <path> (default = src/deps2nix.lock)

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
The process is similar to `buildFlutterApp`
```
{ buildDartApp }:

buildDartApp {
  pname = "pname";
  version = "version";

  # Opitonal: 
  # depsFile = <path> (default = src/deps2nix.lock)
  # dartRuntimeFlags = <list of strings> (default = []) 
  # jit = <bool> (default = false)

  src = ./.;
}
```

## DevShells for Flutter projects
You can create a devShell for Flutter projects with `mkFlutterShell` similar to how you would with `mkShell`.
You can get `mkFlutterShell` through the default overlay (`overlays.default`).

```nix
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ dart-flutter.overlays.default ];
  };
in
{
  devShell = pkgs.mkFlutterShell {
    # Enable if you want to build you app for mobile.
    android = {
      enable = true; # Default: false
      buildToolsVersions = [ "29-0-2" ]; # Default: [ "30-0-3" ]
      platformsAndroidVersions = [ "32" ]; # Default: [ "31" ]
      androidStudio = false; # Default: false
      emulator = false; # Default: false
    };

    # Enable if you want to build your app for the Linux desktop.
    linux = {
      enable = true; # Default: false
    };

    # This function also acts like `mkShell`, so you can still do:
    buildInputs = with pkgs; [
      gst_all_1.gstreamer
      gst_all_1.gst-libav
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      libunwind
      elfutils
      zstd
      orc
    ];
  };
}
```

# Sources
These sources helped me understand how Flutter downloads stuff.
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/flutter/default.nix
- https://github.com/ilkecan/flutter-nix
- https://github.com/tadfisher/nix-dart
