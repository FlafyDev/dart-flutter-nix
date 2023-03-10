{
  lib,
  jdk11,
  gradle,
  androidStudioPackages,
  android-sdk-builder,
}: {
  sdkPackages ? (_sdkPkgs: []),
  androidStudio ? false,
  emulator ? false,
}: let
  android-sdk =
    android-sdk-builder
    (sdkPkgs:
      with sdkPkgs;
        lib.lists.flatten [
          cmdline-tools-latest
          platform-tools
        ]
        ++ (sdkPackages sdkPkgs)
        ++ lib.optional emulator sdkPkgs.emulator);
in {
  shellHook = ''
    export JAVA_HOME=${jdk11.home}
    export ANDROID_SDK_ROOT=${android-sdk}/share/android-sdk
    export ANDROID_HOME=${android-sdk}/share/android-sdk

    if flutter config | grep -q "android-sdk: "; then
      flutter config --android-sdk ""
    fi
  '';

  buildInputs =
    [
      android-sdk
      gradle
      jdk11
      flutter.fhsWrap # Gradle requires fhs
    ]
    ++ lib.optional androidStudio androidStudioPackages.stable;
}
