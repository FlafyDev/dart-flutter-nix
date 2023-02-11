{
  mkPyScript,
  nix,
  nix-prefetch-git
}: (mkPyScript {
  name = "pubspec-nix";
  dependencies = [nix nix-prefetch-git];
  pythonLibraries = ps: with ps; [pyyaml tqdm];
  content = builtins.readFile ./pubspec-nix.py;
})
