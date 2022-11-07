{
  flutter,
  lib,
  cmake,
  ninja,
  pkg-config,
  wrapGAppsHook,
  autoPatchelfHook,
  util-linux,
  libselinux,
  libsepol,
  libthai,
  libdatrie,
  libxkbcommon,
  at-spi2-core,
  xorg,
  dbus,
  gtk3,
  glib,
  pcre,
  pcre2,
  libepoxy,
  git,
  dart,
  bash,
  curl,
  unzip,
  which,
  xz,
  stdenv,
  fetchzip,
  runCommand,
  clang,
  tree,
}: _: {
  shellHook = ''
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [libepoxy]}
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    bash
    curl
    git
    unzip
    which
    xz
  ];

  buildInputs = [
    at-spi2-core.dev
    clang
    cmake
    dart
    dbus.dev
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
    pcre2
    util-linux
  ];
}
