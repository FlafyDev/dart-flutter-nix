{
  callPackage,
  fetchurl,
  dart,
}: let
  mkFlutter = {
    version,
    dartVersion,
    hash,
    dartHash,
  }: callPackage (import ./package.nix {
    pname = "flutter";
    inherit version;

    src = fetchurl {
      url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz";
      sha256 = hash;
    };

    dart = dart.override {
      version = dartVersion;
      sources = {
        "${dartVersion}-x86_64-linux" = fetchurl {
          url = "https://storage.googleapis.com/dart-archive/channels/stable/release/${dartVersion}/sdk/dartsdk-linux-x64-release.zip";
          sha256 = dartHash.x86_64-linux;
        };
        "${dartVersion}-aarch64-linux" = fetchurl {
          url = "https://storage.googleapis.com/dart-archive/channels/stable/release/${dartVersion}/sdk/dartsdk-linux-arm64-release.zip";
          sha256 = dartHash.aarch64-linux;
        };
      };
    };
  }) {};
in {
  stable = mkFlutter {
    #version = "3.3.8";
    #dartVersion = "2.18.4";
    #hash = "sha256-QH+10F6a0XYEvBetiAi45Sfy7WTdVZ1i8VOO4JuSI24=";
    #dartHash = {
    #  x86_64-linux = "sha256-lFw+KaxzhuAMnu6ypczINqywzpiD+8Kd+C/UHJDrO9Y=";
    #  aarch64-linux = "sha256-snlFTY4oJ4ALGLc210USbI2Z///cx1IVYUWm7Vo5z2I=";
    #};
    version = "3.7.7";
    dartVersion = "2.19.4";
    hash = "sha256-zdSVl+iMNeXeUYTprP9DPfuzwHW3Tveyd5Cvf1fOJCA=";
    dartHash = {
      x86_64-linux = "sha256-+FkZRFEoNLoZtNg4PScNf1b+8DxWulPU41wj24DqijM=";
      aarch64-linux = "";
    };
  };
}
