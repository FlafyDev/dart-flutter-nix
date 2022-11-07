# Valid platforms: "linux", "android",
{
  lib,
  mkShell,
  callPackage,
  android-sdk-builder,
  deps2nix,
  flutter,
}: {
  linux ? {enable = false;},
  android ? {enable = false;},
  ...
} @ args: let
  shellLinux =
    if linux.enable
    then callPackage ./platforms/linux.nix {} (builtins.removeAttrs linux ["enable"])
    else {};
  shellAndroid =
    if android.enable
    then callPackage ./platforms/android.nix {inherit android-sdk-builder;} (builtins.removeAttrs android ["enable"])
    else {};

  shells = [args shellLinux shellAndroid];
in
  mkShell ((builtins.removeAttrs args [
      "android"
      "linux"
    ])
    // {
      shellHook = builtins.concatStringsSep "\n" ((map (shell: shell.shellHook or "") shells)
        ++ [
        ]);

      packages =
        (lib.lists.flatten (map (shell: shell.packages or []) shells))
        ++ [
          deps2nix
        ];

      nativeBuildInputs =
        (lib.lists.flatten (map (shell: shell.nativeBuildInputs or []) shells))
        ++ [
          flutter.dart
        ];

      buildInputs =
        (lib.lists.flatten (map (shell: shell.buildInputs or []) shells))
        ++ [
          flutter
        ];
    })
