{
  buildDartApp,
  git,
  which,
  unzip,
  lib,
  flutter,
  runCommand,
  buildFHSUserEnv,
  bash,
  unpackTarball,
  stdenvNoCC,
  wget,
  symlinkCache ? [], # Useful for experimenting with cache files without rebuilding the package.
}: let
  pname = "flutter-elinux";
  name = "${pname}-${version}";

  inherit (flutter) dart;
  inherit (flutter.unwrapped) version;

  flutterSrc = unpackTarball flutter.unwrapped;

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
        export ENGINE_SHORT_REVISION=$(head -c 10 ${flutter.unwrapped}/bin/internal/engine.version)
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
    outputHash = "sha256-cp+5G0zs5JWdgZDu7U3cnTva/7TAw2QFDGz3uuCDUvY=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  unwrapped =
    buildDartApp.override {
      inherit dart;
    } {
      pname = "${pname}-unwrapped";
      inherit version;

      # depsFile = ./patches/elinux/deps2nix.lock;
      deps = {
        dart = {
          executables = {
            flutter-elinux = "flutter_elinux";
          };
        };
        pub = {};
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
      ];

      preConfigure = ''
        cp -rT ${flutterSrc} ./flutter
        chmod -R +w ./flutter/*

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
            flutter.unwrapped.patches
          )}

          HOME=../.. # required for pub upgrade --offline, ~/.pub-cache
                     # path is relative otherwise it's replaced by /build/flutter

          pushd "$FLUTTER_TOOLS_DIR"
            dart pub get --offline
          popd

          local revision="$(cd "$FLUTTER_ROOT"; git rev-parse HEAD)"
          dart --snapshot="$SNAPSHOT_PATH" --packages="$FLUTTER_TOOLS_DIR/.dart_tool/package_config.json" "$SCRIPT_PATH"
          echo "$revision" > "$STAMP_PATH"
          echo -n "${version}" > version

          rm -r bin/cache/dart-sdk
        popd
        export PUB_CACHE="$FLUTTER_ROOT/.pub-cache"

        # TODO: automatically do this based on the folders in `./templates`
        # Right now the folders are: "app" and "plugin".

        mkdir ./flutter/packages/flutter_tools/templates/app/elinux.tmpl
        cp -r ./templates/app/* ./flutter/packages/flutter_tools/templates/app/elinux.tmpl

        mkdir ./flutter/packages/flutter_tools/templates/plugin/elinux.tmpl
        cp -r ./templates/plugin/* ./flutter/packages/flutter_tools/templates/plugin/elinux.tmpl
      '' ;

      preInstall = ''
        mkdir -p $out/lib/flutter/bin/cache/
        cp -r . $out/lib
        ln -sf $(dirname $(dirname $(which dart))) $out/lib/flutter/bin/cache/dart-sdk

        cp -rT ${elinuxVendor}/artifacts $out/lib/flutter/bin/cache/artifacts
      '' + lib.concatStringsSep "\n" (map (cache: ''
        rm -r "$out/lib/flutter/bin/cache/${cache}"
        ln -s "/tmp/flutter-cache/${cache}" "$out/lib/flutter/bin/cache/${cache}"
      '') symlinkCache);
    };
  fhsEnv = buildFHSUserEnv {
    name = "${name}-fhs-env";
    multiPkgs = pkgs:
      with pkgs; [
        # Flutter only use these certificates
        (runCommand "fedoracert" {} ''
          mkdir -p $out/etc/pki/tls/
          ln -s ${cacert}/etc/ssl/certs $out/etc/pki/tls/certs
        '')
        pkgs.zlib
      ];
    targetPkgs = pkgs:
      with pkgs; [
        bash
        curl
        git
        unzip
        which
        xz

        # flutter test requires this lib
        libGLU

        # for android emulator
        alsa-lib
        dbus
        expat
        libpulseaudio
        libuuid
        xorg.libX11
        xorg.libxcb
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXrender
        xorg.libXtst
        libGL
        nspr
        nss
        systemd
      ];
  };
  wrapped =
    runCommand name
    {
      startScript = ''
        #!${bash}/bin/bash
        export PUB_CACHE=''${PUB_CACHE:-"$HOME/.pub-cache"}
        export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
        ${fhsEnv}/bin/${name}-fhs-env ${unwrapped}/bin/flutter-elinux --no-version-check "$@"
      '';
      preferLocalBuild = true;
      allowSubstitutes = false;
      passthru = {
        inherit unwrapped dart;
      };
      meta = with lib; {
        description = "Flutter is Google's SDK for building mobile, web and desktop with Dart";
        longDescription = ''
          Flutter is Google’s UI toolkit for building beautiful,
          natively compiled applications for mobile, web, and desktop from a single codebase.
        '';
        homepage = "https://flutter.dev";
        license = licenses.bsd3;
        platforms = ["x86_64-linux" "aarch64-linux"];
        maintainers = [];
      };
    } ''
      mkdir -p $out/bin/cache/
      ln -sf ${dart} $out/bin/cache/dart-sdk
      echo -n "$startScript" > $out/bin/${pname}
      chmod +x $out/bin/${pname}
    '';
in
  wrapped
