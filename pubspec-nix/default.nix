{
  mkPyScript,
  nix,
  flutter,
  nix-prefetch-git
}: (mkPyScript {
  name = "pubspec-nix";
  dependencies = [nix flutter.unwrapped nix-prefetch-git];
  pythonLibraries = ps: with ps; [pyyaml tqdm];
  content = builtins.readFile ./pubspec-nix.py;
})
