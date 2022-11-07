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
, pcre2
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
, jdk11
, gradle
, androidStudioPackages
  # , androidSdkPackages
, android-sdk-builder
}:

{ buildToolsVersions ? [ "30-0-3" ]
, platformsAndroidVersions ? [ "31" ]
, androidStudio ? false
, emulator ? false
}:
let
  android-sdk =
    android-sdk-builder
      (sdkPkgs: with sdkPkgs; lib.lists.flatten [
        cmdline-tools-latest
        platform-tools

        # platforms-android-31
        # build-tools-30-0-3
        (map (ver: sdkPkgs."platforms-android-${ver}") platformsAndroidVersions)
        (map (ver: sdkPkgs."build-tools-${ver}") buildToolsVersions)
      ] ++ lib.optional emulator sdkPkgs.emulator);
in

{
  shellHook = ''
    export JAVA_HOME=${jdk11.home}
    export ANDROID_SDK_ROOT=${android-sdk}/share/android-sdk
    export ANDROID_HOME=${android-sdk}/share/android-sdk

    if flutter config | grep -q "android-sdk: "; then
      flutter config --android-sdk ""
    fi
  '';

  buildInputs = [
    android-sdk
    gradle
    jdk11
  ] ++ lib.optional androidStudio androidStudioPackages.stable;
}
