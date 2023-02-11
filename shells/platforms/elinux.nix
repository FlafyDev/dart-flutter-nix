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
}: _: {
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

  buildInputs = [
    wayland
    wayland-protocols
    wlr-protocols
    wayland-utils
    egl-wayland
    mesa
    libglvnd
    flutter-elinux

    # drm
    libdrm
    libinput
    eudev
    systemd
  ];
}
