# Assumes "linux" shell is also enabled
{
  lib,
  libxkbcommon,
  libdrm,
  libinput,
  eudev,
  systemd,
  gnumake,
  wayland,
  wayland-protocols,
  wlr-protocols,
  wayland-utils,
  egl-wayland,
  mesa,
  libglvnd,
  flutter-elinux,
}: {exposeAsFlutter ? false}: {
  shellHook = ''
    export LD_LIBRARY_PATH=''$LD_LIBRARY_PATH:${lib.makeLibraryPath [
      libxkbcommon
      wayland
      mesa
      libglvnd
      libdrm
      libinput
      eudev
      systemd
    ]}
  '';

  nativeBuildInputs = [
    gnumake
  ];

  buildInputs = let
    flutter-elinux-mod =
      if exposeAsFlutter
      then (flutter-elinux.makeWrapper {executableName = "flutter";})
      else flutter-elinux;
  in [
    wayland
    wayland-protocols
    wlr-protocols
    wayland-utils
    egl-wayland
    mesa
    libglvnd
    flutter-elinux-mod

    # drm
    libdrm
    libinput
    eudev
    systemd
  ];
}
