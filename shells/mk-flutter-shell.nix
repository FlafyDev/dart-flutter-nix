# Valid platforms: "linux", "android",
{
  lib,
  mkShell,
  callPackage,
  android-sdk-builder,
  pubspec-nix,
  flutter,
}: {
  linux ? {enable = false;},
  elinux ? {enable = false;},
  android ? {enable = false;},
  ...
} @ args: let
  shellLinux =
    if linux.enable
    then callPackage ./platforms/linux.nix {} (builtins.removeAttrs linux ["enable"])
    else {};
  shellELinux =
    if elinux.enable
    then callPackage ./platforms/elinux.nix {} (builtins.removeAttrs elinux ["enable"])
    else {};
  shellAndroid =
    if android.enable
    then callPackage ./platforms/android.nix {inherit android-sdk-builder;} (builtins.removeAttrs android ["enable"])
    else {};

  shells = [shellLinux shellELinux shellAndroid args];
in
  mkShell ((builtins.removeAttrs args [
      "android"
      "linux"
      "elinux"
    ])
    // {
      shellHook = builtins.concatStringsSep "\n" ((map (shell: shell.shellHook or "") shells)
        ++ [
        ]);

      packages =
        (lib.lists.flatten (map (shell: shell.packages or []) shells))
        ++ [
          pubspec-nix
        ];

      nativeBuildInputs =
        (lib.lists.flatten (map (shell: shell.nativeBuildInputs or []) shells))
        ++ [
          flutter.dart
        ];

      buildInputs =
        (lib.lists.flatten (map (shell: shell.buildInputs or []) shells))
        ++ [
          flutter.fhsWrap # Use FHS for dev shell flutter. (Gradle requires fhs)
        ];
    })
