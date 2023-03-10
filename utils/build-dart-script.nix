# Usage:
# ```nix 
#   pkgs.buildDartScript "my-script-1" {} ''
#     void main() {
#       print('Hello, World!');
#     }
#   ''
# ```
#
# ```nix
#   pkgs.buildDartScript "my-script-2" {
#     isolated = true;
#     dependencies = [ pkgs.pandoc ];
#     
#   } ''
#     void main() {
#       print('Hello, World!');
#     }
#   ''
# ```
#
# ```nix
#   pkgs.buildDartScript "my-script-3" {} ./main.dart
# ```
#
# ```nix
#   pkgs.buildDartScript "my-script-4" {} ./src    # Contains main.dart
# ```

{
  buildDartApp,
  dart,
  writeText,
  writeTextDir,
  runCommand,
  makeWrapper,
  lib,
}:
name:
{
  dependencies ? [],
  isolated ? true,
  dartVersion ? dart.version,
  ...
}@args: content: let
  inherit (builtins) removeAttrs;
  inherit (lib) makeBinPath;
  inherit (lib.strings) stringAsChars;

  dartName = stringAsChars (x: if x == "-" then "_" else x) name;

  # Generate a pubspec.yaml file
  pubspec = writeText "pubspec.yaml" ''
    name: ${dartName}
    environment:
      sdk: '>=${dartVersion} <3.0.0'
    executable:
      executable: main
  '';

  pubspecLock = writeText "pubspec.lock" ''
    packages: {}
    sdks:
      dart: ">=${dartVersion} <3.0.0"
  '';

  pubspecNixLockFile = writeText "pubspec-nix.lock" (builtins.toJSON {
    dart = {
      executables = {
        executable = "main";
      };
    };
    pub = {};
  });

  # Content could be either a string, path to a file or a path to a directory.
  # `binDir` is a varialbe that will always be a path to a directory with a main.dart file.
  binDir = if builtins.isString content then
    writeTextDir "main.dart" content
  else if builtins.isPath content then
    if builtins.pathExists (content + "/main.dart") then
      content
    else
      runCommand "main.dart" { } ''
        mkdir -p $out
        cp ${content} $out/main.dart
      ''
  else
    throw "Invalid content type: ${builtins.typeOf content}";

  src = runCommand "${name}-src" { } ''
    mkdir -p $out
    cp -r ${binDir} $out/bin
    cp ${pubspec} $out/pubspec.yaml
    cp ${pubspecLock} $out/pubspec.lock
    cp ${pubspecNixLockFile} $out/pubspec-nix.lock
  '';
in
  buildDartApp ((removeAttrs args [
    "dependencies" "isolated"
    "pname" "version"
  ]) // {
    inherit name src;

    buildInputs = [
      makeWrapper
    ] ++ (args.buildInputs or []);

    fixupPhase = let
      wrapCmd = "wrapProgram $out/bin/${dartName} --${if isolated then "set" else "suffix"} PATH ${makeBinPath dependencies}";
    in ''
      mv $out/bin/executable $out/bin/${dartName}
      ${wrapCmd}
      ${args.fixupPhase or ""}
    '';
  })
