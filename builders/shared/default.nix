{
  lib,
  fetchzip,
  runCommand,
}: {
  generatePubCache = {
    deps,
    pname,
  }: (runCommand "${pname}-pub-cache" {} ([''mkdir -p "$out"'']
    ++ (lib.mapAttrsToList
      (path: dep: let
        derv = fetchzip dep;
      in ''
        mkdir -p $out/${dirOf path}
        ln -s ${derv} $out/${path}
      '')
      deps.pub)));
}
