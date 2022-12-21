{
  mkPyScript,
  flutter,
}: (mkPyScript {
  name = "deps2nix";
  dependeinces = [flutter];
  pythonLibraries = ps: with ps; [pyyaml tqdm];
  content = builtins.readFile ./deps2nix.py;
})
