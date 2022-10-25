{ lib, fetchzip, runCommand }:

{
  generatePubCache = { deps, args }: (runCommand "${args.pname}-pub-cache" { } (lib.mapAttrsToList
    (path: dep:
      let
        derv = fetchzip dep;
      in
      ''
        mkdir -p $out/${dirOf path}
        ln -s ${derv} $out/${path}
      '')
    deps.pub));
}
