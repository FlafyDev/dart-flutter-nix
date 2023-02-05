{
  lib,
  fetchzip,
  fetchgit,
  runCommand,
}: {
  generatePubCache = {
    pubspecNixLock,
    args,
  }:
    runCommand "${args.pname}-pub-cache" {} (lib.mapAttrsToList (
        path: dep: let
          fetcher =
            {inherit fetchzip fetchgit;}.${dep.fetcher}
            or (throw "Unknown fetcher: ${dep.fetcher}");
          derv = fetcher dep.args;
        in
          ''
            mkdir -p $out/${dirOf path}
            ln -s ${derv} $out/${path}
          ''
          # https://github.com/dart-lang/pub/blob/12a2af4de1e85994eae5679c7a7ed082c5a557f5/lib/src/source/git.dart#L338
          + (lib.optionalString (dep.fetcher == "fetchgit") ''
            local CACHE_DIR=$out/git/cache/${dep.repo_name}-$(echo -n ${dep.args.url} | sha1sum | awk '{print $1}')
            mkdir -p $(dirname $CACHE_DIR)
            ln -s ${derv}/.git $CACHE_DIR
          '')
      )
      pubspecNixLock.pub);
}
