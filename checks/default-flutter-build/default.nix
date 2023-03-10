{
  buildFlutterApp,
  flutter,
  runCommand,
}: let
  src =
    runCommand "flutter-default-app-src" {
      nativeBuildInputs = [flutter];
    } ''
      export HOME=/tmp
      flutter create app --no-pub
      cp ${./pubspec.lock} ./
      cp -rT app $out
    '';

  pubspecNixLockFile = ./pubspec-nix.lock;
  # pubspecNixLockFile = stdenvNoCC.mkDerivation {
  #   name = "pubspec-nix-lock";
  #   inherit src;
  #   buildInputs = [pubspec-nix];
  #   buildPhase = ''
  #     pubspec-nix --no-hash
  #   '';
  #   installPhase = ''
  #     cp pubspec-nix.lock $out
  #   '';
  # };
in
  buildFlutterApp {
    pname = "flutter-default-app";
    version = "1.0.0";

    inherit pubspecNixLockFile src;
  }
