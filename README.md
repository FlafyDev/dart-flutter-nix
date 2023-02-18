# dart-flutter-nix

Tools for compiling Flutter, Dart, and [Flutter eLinux](https://github.com/sony/flutter-embedded-linux) projects with Nix

## Examples
[github:FlafyDev/guifetch](https://github.com/FlafyDev/guifetch) - Flutter project  
[github:FlafyDev/listen_blue](https://github.com/FlafyDev/listen_blue) - Flutter project  

## Packaging a Flutter project
###### Tested versions: Flutter v3.0.4, v3.3.3, v3.3.8
### 1. run `pubspec-nix`
```nix
system: let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ dart-flutter.overlays.default ];
  }; 
in {
  devShell = pkgs.mkShell {
    packages = [
      pkgs.pubspec-nix
    ];
  };
}
```

Once you have `pubspec-nix`, run it at the root of your Flutter project and wait for it to download everything.  

After `pubspec-nix` is done, a file named `pubspec-nix.lock` will be created at the root of your Flutter project.  
This file will be used to generate Pub's cache directory inside the Nix derivation.

### 2. Making a derivation with `buildFlutterApp`
Now that you have the `pubspec-nix.lock`. All that's left is to make a package with `buildFlutterApp`:
```nix
{ buildFlutterApp }:

buildFlutterApp {
  pname = "pname";
  version = "version";

  # Optional: 
  # pubspecNixLockFile = <path> (default = src/pubspec-nix.lock)

  src = ./.;
}
```
`pubspecNixLockFile` can be set to override the default location of `pubspec-nix.lock`.
Setting `configurePhase`, `buildPhase`, or `installPhase` will do nothing. Consider using `pre<Phase>` and `post<Phsae>` instead.

##### To explicitly state which Flutter to use.
```nix
pkgs.callPackage ./package.nix {
  buildFlutterApp = pkgs.buildFlutterApp.override {
    flutter = pkgs.flutter2;
  };
}
```


## Packaging a Dart project
The process is similar to packaging a Flutter project.
```nix
{ buildDartApp }:

buildDartApp {
  pname = "pname";
  version = "version";

  # Optional: 
  # pubspecNixLockFile = <path> (default = src/pubspec-nix.lock)
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
    # Enable if you want to build you app for Android.
    android = {
      enable = true; # Default: false
      sdkPackages = sdkPkgs:
        with sdkPkgs; [
          build-tools-29-0-2
          platforms-android-32
        ];
      androidStudio = false; # Default: false
      emulator = false; # Default: false
    };

    # Enable if you want to build your app for the Linux desktop.
    linux = {
      enable = true; # Default: false
    };

    # Enable if you want to build your app with Flutter eLinux.
    elinux = {
      enable = true;
      exposeAsFlutter = true; # Default: false - Changes the executable's name from "flutter-elinux" to "flutter"
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

## Running checks
```console
nix flake check --no-sandbox -L 
```
- `--no-sandbox` Because it also tests pubspec-nix which gets the Pub packages without hashing them (`pubspec-nix --no-hash`) so later Nix has to download these Pub packages without hashes, hence Nix needs access to the internet.  
(`pubspec-nix` doesn't do any hashing in the flake's checks. This is due to pubspec-nix being unable to access nix store inside a derivation (even when not sandboxed) which makes the commands `nix-prefetch-*` fail.)  

- `-L` Logging

## Sources
These sources helped me understand how Flutter downloads stuff.
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/flutter/default.nix
- https://github.com/ilkecan/flutter-nix
- https://github.com/tadfisher/nix-dart
