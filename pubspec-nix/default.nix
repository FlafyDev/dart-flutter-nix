{
  nix,
  nix-prefetch-git,
  dart,
  buildDartApp,
}:
buildDartApp {
  name = "dart-flutter-nix";
  buildInputs = [nix nix-prefetch-git];
  src = ./.;
  version = "1.0.0";
}
