{
  buildDartApp,
  git,
  which,
  unzip,
  lib,
  flutter,
  autoPatchelfHook,
  unpackTarball,
  stdenvNoCC,
  wget,
  symlinkCache ? [], # Useful for experimenting with cache files without rebuilding the package.
  gtk3,
  libepoxy,
  libglvnd,
  libxkbcommon,
  libdrm,
  libinput,
  systemd,
  eudev,
  libgccjit, # libstdc++.so.6
  mesa,
  wayland,
  xorg,
}: let
  pname = "flutter-elinux";

  inherit (flutter) dart;
  inherit (flutter) version;

  flutterSrc = unpackTarball flutter;

  # Download all the artifacts for elinux engine.
  # This is all in a single derivation because there are a lot of artifacts to get hashes for.
  elinuxVendor = stdenvNoCC.mkDerivation {
    pname = "${pname}-vendor";
    inherit version;
    phases = ["installPhase"];
    nativeBuildInputs = [wget unzip];
    installPhase =
      ''
        mkdir -p "$out"
        mkdir -p "$out/artifacts/engine"
        export ENGINE_SHORT_REVISION=$(head -c 10 ${flutter}/bin/internal/engine.version)
      ''
      + (lib.concatStringsSep "\n" (map (artifact: ''
          wget https://github.com/sony/flutter-embedded-linux/releases/download/$ENGINE_SHORT_REVISION/${artifact}.zip --no-check-certificate
          unzip ./${artifact}.zip -d "$out/artifacts/engine/${artifact}"
        '') [
          "elinux-arm64-debug"
          "elinux-arm64-profile"
          "elinux-arm64-release"
          "elinux-common"
          "elinux-x64-debug"
          "elinux-x64-profile"
          "elinux-x64-release"
        ]))
      + ''
        wget "https://github.com/sony/flutter-elinux/archive/refs/tags/${version}.tar.gz" -O "$out/elinux-src.tar.gz" --no-check-certificate
      '';

    # outputHash = lib.fakeSha256;
    outputHash = "sha256-qg0oUGnYcOJrxpYS+QB6lnFb/09OYpmgmfiIf1tVzrI=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  elinux =
    buildDartApp.override {
      inherit dart;
    } {
      pname = "${pname}";
      inherit version;

      passthru = {
        inherit dart;
        fhsWrap = flutter.makeFhsWrapper {
          derv = elinux;
          executableName = "flutter-elinux";
        };
      };

      pubspecNixLock =
        (builtins.fromJSON (builtins.readFile ./pubspec-nix.lock))
        // {
          dart = {
            executables = {
              flutter-elinux = "flutter_elinux";
            };
          };
        };

      jit = true;

      patches = [
        ./patches/elinux/pubspec.patch
        ./patches/elinux/create.patch
      ];

      postPatch = ''
        patchShebangs --build ./bin/
      '';

      src = "${elinuxVendor}/elinux-src.tar.gz";

      # outputHash = lib.fakeSha256;
      # outputHash = "sha256-EpXV9VRhq/NA/Xa9eXped38pmOkmNKLyhICI06PCpKo=";
      # outputHashAlgo = "sha256";
      # outputHashMode = "recursive";

      nativeBuildInputs = [
        git
        unzip
        which
        autoPatchelfHook
      ];

      buildInputs = [
        gtk3
        libepoxy
        libglvnd
        libxkbcommon
        libdrm
        libinput
        systemd
        eudev
        libgccjit # libstdc++.so.6
        wayland
        xorg.libX11
        mesa
      ];

      preConfigure = ''
        cp -rT ${flutterSrc} ./flutter
        chmod -R +w ./flutter/*

        export OG_PUB_CACHE=$PUB_CACHE
        unset PUB_CACHE
        pushd ./flutter
          export FLUTTER_ROOT="$(pwd)"
          export FLUTTER_TOOLS_DIR="$FLUTTER_ROOT/packages/flutter_tools"
          export SCRIPT_PATH="$FLUTTER_TOOLS_DIR/bin/flutter_tools.dart"

          export SNAPSHOT_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
          export STAMP_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.stamp"

          export DART_SDK_PATH="$(which dart)"

          # Patch ./flutter
          ${lib.concatStringsSep "\n" (
          map (patch: "patch -p1 < ${patch}")
          flutter.patches
        )}

          HOME=$out

          pushd "$FLUTTER_ROOT"
            dart pub cache preload ./.pub-preload-cache/*
          popd

          pushd "$FLUTTER_TOOLS_DIR"
            dart pub get --offline
          popd

          local revision="$(cd "$FLUTTER_ROOT"; git rev-parse HEAD)"
          dart --snapshot="$SNAPSHOT_PATH" --packages="$FLUTTER_TOOLS_DIR/.dart_tool/package_config.json" "$SCRIPT_PATH"
          echo "$revision" > "$STAMP_PATH"
          echo -n "${version}" > version

          rm -r bin/cache/dart-sdk
        popd
        # export PUB_CACHE="$FLUTTER_ROOT/.pub-cache"
        export PUB_CACHE=$OG_PUB_CACHE

        # TODO: automatically do this based on the folders in `./templates`
        # Right now the folders are: "app" and "plugin".

        mkdir ./flutter/packages/flutter_tools/templates/app/elinux.tmpl
        cp -r ./templates/app/* ./flutter/packages/flutter_tools/templates/app/elinux.tmpl

        mkdir ./flutter/packages/flutter_tools/templates/plugin/elinux.tmpl
        cp -r ./templates/plugin/* ./flutter/packages/flutter_tools/templates/plugin/elinux.tmpl
      '';

      preInstall =
        ''
          mkdir -p $out/lib/flutter/bin/cache/
          cp -r . $out/lib
          ln -sf $(dirname $(dirname $(which dart))) $out/lib/flutter/bin/cache/dart-sdk

          cp -rT ${elinuxVendor}/artifacts $out/lib/flutter/bin/cache/artifacts
        ''
        + lib.concatStringsSep "\n" (map (cache: ''
            rm -r "$out/lib/flutter/bin/cache/${cache}"
            ln -s "/tmp/flutter-cache/${cache}" "$out/lib/flutter/bin/cache/${cache}"
          '')
          symlinkCache);

      postFixup = ''
        sed -i '2i\
        export PUB_CACHE=\''${PUB_CACHE:-"\$HOME/.pub-cache"}\
        export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
        ' $out/lib/bin/flutter-elinux
      '';
    };
in
  elinux
