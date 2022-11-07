{
  lib,
  dart,
  callPackage,
  makeWrapper,
  stdenv,
}: args: let
  inherit
    (lib)
    importJSON
    mapAttrsToList
    concatStringsSep
    ;

  shared = callPackage ./shared {};
  jit = args.jit or false;

  deps = importJSON (args.depsFile or (args.src + "/deps2nix.lock"));
  inherit (deps.dart) executables;

  pubCache = shared.generatePubCache {inherit deps args;};
  buildCommands = builtins.concatStringsSep "\n" (mapAttrsToList
    (_execName: dartFile:
      if jit
      then "dart --snapshot=./bin/${dartFile}.jit ./bin/${dartFile}.dart"
      else "dart compile aot-snapshot ./bin/${dartFile}.dart")
    executables);

  installSnapshotsCommands = builtins.concatStringsSep "\n" (mapAttrsToList
    (execName: dartFile: let
      flags = concatStringsSep " " (args.dartRuntimeFlags or []);
    in
      if jit
      then let 
        jitPath = "$out/lib/dart-${args.pname}-${args.version}/${dartFile}.jit";
      in ''
        cp bin/${dartFile}.jit ${jitPath}
        makeWrapper ${dart}/bin/dart $out/bin/${execName} --argv0 "${execName}" --add-flags "${flags} ${jitPath}"
      ''
      else let
        aotPath = "$out/lib/dart-${args.pname}-${args.version}/${dartFile}.aot";
      in ''
        cp bin/${dartFile}.aot ${aotPath}
        makeWrapper ${dart}/bin/dartaotruntime $out/bin/${execName} --argv0 "${execName}" --add-flags "${flags} ${aotPath}"
      '')
    executables);
in
  stdenv.mkDerivation (args
    // {
      nativeBuildInputs =
        [
          makeWrapper
        ]
        ++ (args.nativeBuildInputs or []);

      buildInputs =
        [
          dart
        ]
        ++ (args.buildInputs or []);

      PUB_CACHE = toString pubCache;

      configurePhase = ''
        runHook preConfigure

        HOME=$(mktemp -d)

        dart pub get --offline

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        ${buildCommands}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/dart-${args.pname}-${args.version}
        mkdir -p $out/bin

        ${installSnapshotsCommands}

        runHook postInstall
      '';
    })
