{
  mkPyScript,
  nix,
  flutter,
  nix-prefetch-git
}: (mkPyScript {
  name = "deps2nix";
  # FIXME: fix typo "dependeinces"
  dependeinces = [nix flutter.unwrapped nix-prefetch-git];
  pythonLibraries = ps: with ps; [pyyaml tqdm];
  content = builtins.readFile ./deps2nix.py;
})
