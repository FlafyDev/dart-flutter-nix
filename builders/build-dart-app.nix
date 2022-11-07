{ flutter
, lib
, cmake
, ninja
, pkg-config
, wrapGAppsHook
, autoPatchelfHook
, util-linux
, libselinux
, libsepol
, libthai
, libdatrie
, libxkbcommon
, at-spi2-core
, xorg
, dbus
, gtk3
, glib
, pcre
, pcre2
, libepoxy
, git
, dart
, bash
, curl
, unzip
, which
, xz
, stdenv
, fetchzip
, runCommand
, clang
, tree
, callPackage
, writeShellScript
, makeWrapper
}:

args:

let
  inherit (lib)
    importJSON
    mapAttrsToList
    makeLibraryPath
    ;

  shared = callPackage ./shared { };

  deps = importJSON (args.depsFile or (args.src + "/deps2nix.lock"));
  executables = deps.dart.executables;

  pubCache = shared.generatePubCache { inherit deps args; };
  buildCommands = builtins.concatStringsSep "\n" (mapAttrsToList
    (execName: dartFile:
      "dart compile aot-snapshot ./bin/${dartFile}.dart")
    executables);

  installSnapshotsCommands = builtins.concatStringsSep "\n" (mapAttrsToList
  (execName: dartFile: let
    aotPath = "$out/lib/dart-${args.pname}-${args.version}/${dartFile}.aot";
  in ''
      cp bin/${dartFile}.aot ${aotPath} 
      makeWrapper ${dart}/bin/dartaotruntime $out/bin/${execName} --argv0 "${execName}" --add-flags "${aotPath}"
    '')
    executables);
in
stdenv.mkDerivation (args // rec {
  nativeBuildInputs = [
    makeWrapper
  ] ++ (args.nativeBuildInputs or [ ]);

  buildInputs = [
    dart
  ] ++ (args.buildInputs or [ ]);

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