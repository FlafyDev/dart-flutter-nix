{
  lib,
  python,
  stdenvNoCC,
  makeWrapper,
  writeText,
}: {
  name,
  pythonLibraries ? (ps: []),
  dependencies ? [],
  isolate ? true,
  content,
}:
stdenvNoCC.mkDerivation {
  inherit name;
  buildInputs = [makeWrapper (python.withPackages pythonLibraries)];
  unpackPhase = "true";
  installPhase = let
    wrap =
      if isolate
      then "wrapProgram $out/bin/${name} --set PATH ${lib.makeBinPath dependencies}"
      else "wrapProgram $out/bin/${name} --suffix PATH : ${
        lib.makeBinPath dependencies
      }";

    file = writeText "${name}-py-file" "#!/usr/bin/env python\n\n${content}";
  in ''
    mkdir -p $out/bin
    cp ${file} $out/bin/${name}
    chmod +x $out/bin/${name}
    ${wrap}
  '';
}
