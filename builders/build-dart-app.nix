{
  lib,
  dart,
  git,
  makeWrapper,
  stdenv,
  generatePubCache,
}: args: let
  inherit
    (lib)
    importJSON
    mapAttrsToList
    concatStringsSep
    ;

  name = args.name or "${args.pname}-${args.version}";
  jit = args.jit or false;

  pubspecNixLock = args.pubspecNixLock or (importJSON (args.pubspecNixLockFile or (args.src + "/pubspec-nix.lock")));
  inherit (pubspecNixLock.dart) executables;

  pubCache = generatePubCache {
    inherit pubspecNixLock;
    inherit name;
  };

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
        jitPath = "$out/lib/dart-${name}/${dartFile}.jit";
      in ''
        cp bin/${dartFile}.jit ${jitPath}
        makeWrapper ${dart}/bin/dart $out/bin/${execName} --argv0 "${execName}" --add-flags "${flags} ${jitPath}"
      ''
      else let
        aotPath = "$out/lib/dart-${name}/${dartFile}.aot";
      in ''
        cp bin/${dartFile}.aot ${aotPath}
        makeWrapper ${dart}/bin/dartaotruntime $out/bin/${execName} --argv0 "${execName}" --add-flags "${flags} ${aotPath}"
      '')
    executables);
in
  stdenv.mkDerivation ((builtins.removeAttrs args [
      "pubspecNixLock"
      "pubspecNixLockFile"
    ])
    // {
      nativeBuildInputs =
        [
          git
          makeWrapper
        ]
        ++ (args.nativeBuildInputs or []);

      buildInputs =
        [
          dart
        ]
        ++ (args.buildInputs or []);

      PUB_CACHE = args.PUB_CACHE or (toString pubCache);

      configurePhase = ''
        runHook preConfigure

        HOME=$(mktemp -d)

        git config --global --add safe.directory '*'
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

        mkdir -p $out/lib/dart-${name}
        mkdir -p $out/bin

        ${installSnapshotsCommands}

        runHook postInstall
      '';
    })
