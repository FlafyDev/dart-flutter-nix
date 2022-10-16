{ mkPyScript, nix, flutter }:

(mkPyScript {
  name = "deps2nix";
  dependeinces = [ nix flutter.unwrapped ];
  pythonLibraries = ps: with ps; [ pyyaml tqdm ];
  content = builtins.readFile ./deps2nix.py;
})
