{
  stdenv,
  gnutar,
}: d:
stdenv.mkDerivation {
  name = "${d.src.name}-unpacked";
  phases = ["installPhase"];
  nativeBuildInputs = [gnutar];
  installPhase = ''
    mkdir "$out"
    tar xf "${d.src}" --strip-components=1 -C "$out"
  '';
}
