{ flutter
, lib
, cmake
, ninja
, pkg-config
, wrapGAppsHook
, autoPatchelfHook
, util-linux
, libselinux
, libsepol
, libthai
, libdatrie
, libxkbcommon
, at-spi2-core
, xorg
, dbus
, gtk3
, glib
, pcre
, libepoxy
, git
, dart
, bash
, curl
, unzip
, which
, xz
, stdenv
, fetchzip
, runCommand
, clang
, tree
}:

args:

let
  inherit (lib)
    importJSON
    mapAttrsToList
    makeLibraryPath
    ;

  deps = importJSON (args.depsFile or (args.src + "/deps2nix.lock"));

  pubCache = (runCommand "${args.pname}-pub-cache" { } (mapAttrsToList
    (path: dep:
      let
        derv = fetchzip dep;
      in
      ''
        mkdir -p $out/${dirOf path}
        ln -s ${derv} $out/${path}
      '')
    deps.pub));

  # ~/.cache/flutter/<cache files>
  cache = (runCommand "${args.pname}-cache" { } ((mapAttrsToList
    (_name: sdk:
      let
        derv = fetchzip (removeAttrs sdk [ "cachePath" ]);
      in
      ''
        mkdir -p $out/${sdk.cachePath}
        ln -s ${derv}/* $out/${sdk.cachePath}
      '')
    deps.sdk.artifacts) ++ (mapAttrsToList
    (name: version: ''
      echo ${version} > $out/${name}.stamp
    '')
    deps.sdk.stamps)));
in
stdenv.mkDerivation (args // rec {
  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    wrapGAppsHook
    autoPatchelfHook
    bash
    curl
    flutter.dart
    git
    unzip
    which
    xz

    # Testing
    tree
  ] ++ (args.nativeBuildInputs or [ ]);

  buildInputs = [
    at-spi2-core.dev
    clang
    cmake
    dart
    dbus.dev
    flutter
    gtk3
    libdatrie
    libepoxy.dev
    libselinux
    libsepol
    libthai
    libxkbcommon
    ninja
    pcre
    pkg-config
    util-linux.dev
    xorg.libXdmcp
    xorg.libXtst
    gtk3
    glib
    pcre
    util-linux
  ] ++ (args.buildInputs or [ ]);

  PUB_CACHE = toString pubCache;
  LD_LIBRARY_PATH = makeLibraryPath [ libepoxy ];
  NIX_LDFLAGS = "-rpath ${lib.makeLibraryPath buildInputs}";

  configurePhase = ''
    runHook preConfigure

    HOME=$(mktemp -d)

    mkdir -p $HOME/.cache/flutter
    cp -r ${cache}/* $HOME/.cache/flutter
    chmod +wr -R $HOME/.cache/flutter

    # Test directories
    # tree $HOME/.cache/flutter
    # tree $PUB_CACHE -L 3

    flutter config --no-analytics &>/dev/null # mute first-run
    flutter config --enable-linux-desktop

    flutter pub get --offline

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    flutter build linux -v || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    built=build/linux/*/release/bundle

    mkdir -p $out/bin
    mv $built $out/app

    for f in $(find $out/app -iname "*.desktop" -type f); do
      install -D $f $out/share/applications/$(basename $f)
    done

    for f in $(find $out/app -maxdepth 1 -type f); do
      ln -s $f $out/bin/$(basename $f)
    done

    # this confuses autopatchelf hook otherwise
    rm -rf "$HOME"

    # make *.so executable
    find $out/app -iname "*.so" -type f -exec chmod +x {} +

    # remove stuff like /build/source/packages/ubuntu_desktop_installer/linux/flutter/ephemeral
    for f in $(find $out/app -executable -type f); do
      if patchelf --print-rpath "$f" | grep /build; then # this ignores static libs (e,g. libapp.so) also
        echo "strip RPath of $f"
        newrp=$(patchelf --print-rpath $f | sed -r "s|/build.*ephemeral:||g" | sed -r "s|/build.*profile:||g")
        patchelf --set-rpath "$newrp" "$f"
      fi
    done

    runHook postInstall
  '';

  # outputHash = lib.fakeSha256;
  # outputHashAlgo = "sha256";
  # dontUseCmakeConfigure = true;
})
