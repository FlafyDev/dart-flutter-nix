{
  pname,
  version,
  dart,
  src,
}: {
  bash,
  buildFHSUserEnv,
  cacert,
  git,
  runCommand,
  stdenv,
  lib,
  alsa-lib,
  dbus,
  expat,
  libpulseaudio,
  libuuid,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXfixes,
  libXrender,
  libXtst,
  libXi,
  libXext,
  libGL,
  nspr,
  nss,
  systemd,
  which,
  symlinkCache ? [], # Useful for experimenting with cache files without rebuilding the package.
}: let
  name = "${pname}-${version}";
  unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit src version;

    patches = [
      ./patches/disable-auto-update.patch
      ./patches/git-dir.patch
      ./patches/move-cache.patch
      ./patches/copy-without-perms.patch
    ];

    postPatch = ''
      patchShebangs --build ./bin/
    '';

    buildInputs = [dart];

    buildPhase =
      ''
        export FLUTTER_ROOT="$(pwd)"
        export FLUTTER_TOOLS_DIR="$FLUTTER_ROOT/packages/flutter_tools"
        export SCRIPT_PATH="$FLUTTER_TOOLS_DIR/bin/flutter_tools.dart"

        export SNAPSHOT_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
        export STAMP_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.stamp"

        export DART_SDK_PATH="$(which dart)"

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

        # rm -r bin/cache/{artifacts,dart-sdk,downloads}
        # rm bin/cache/*.stamp
      ''
      + lib.concatStringsSep "\n" (map (cache: ''
          rm -r "bin/cache/${cache}"
          ln -s "/tmp/flutter-cache/${cache}" "bin/cache/${cache}"
        '')
        symlinkCache);

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out
      mkdir -p $out/bin/cache/
      ln -sf ${dart} $out/bin/cache/dart-sdk

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckInputs = [which git];
    installCheckPhase = ''
      runHook preInstallCheck

      export HOME="$(mktemp -d)"
      $out/bin/flutter config --android-studio-dir $HOME
      $out/bin/flutter config --android-sdk $HOME
      $out/bin/flutter --version | fgrep -q '${version}'

      runHook postInstallCheck
    '';
  };

  # Flutter only use these certificates
  cert = runCommand "fedoracert" {} ''
    mkdir -p $out/etc/pki/tls/
    ln -s ${cacert}/etc/ssl/certs $out/etc/pki/tls/certs
  '';

  # Wrap flutter inside an fhs user env to allow execution of binary,
  # like adb from $ANDROID_HOME or java from android-studio.
  fhsEnv = buildFHSUserEnv {
    name = "${name}-fhs-env";
    multiPkgs = pkgs: [
      cert
      pkgs.zlib
    ];
    targetPkgs = pkgs:
      with pkgs; [
        bash
        curl
        dart
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
        libX11
        libxcb
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXrender
        libXtst
        libGL
        nspr
        nss
        systemd
      ];
  };

  wrapper =
    runCommand name
    {
      startScript = ''
        #!${bash}/bin/bash
        export PUB_CACHE=''${PUB_CACHE:-"$HOME/.pub-cache"}
        export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
        ${fhsEnv}/bin/${name}-fhs-env ${unwrapped}/bin/flutter --no-version-check "$@"
      '';
      preferLocalBuild = true;
      allowSubstitutes = false;
      passthru = {
        inherit dart unwrapped cert;
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
      ln -sf ${dart}/bin/dart $out/bin
      echo -n "$startScript" > $out/bin/${pname}
      chmod +x $out/bin/${pname}
    '';
in
  wrapper
