from os import listdir
from os.path import isfile, join, dirname
from posixpath import join as urljoin
from shutil import which
import subprocess
import json
import yaml
from tqdm import tqdm
import logging

pbar: tqdm
log = logging.getLogger(__name__)


def _prefetch_hosted_package(name, base_url, version) -> dict:
    url = urljoin(
        base_url,
        "packages",
        name,
        "versions",
        f"{version}.tar.gz",
    )
    sha256 = _prefetch_package_url(
        name,
        url,
    )

    nixArgs = {
        "name": f"pub-{name}-{version}",
        "url": url,
        "stripRoot": False,
        "sha256": sha256
    }
    return { "fetcher": "zip", "args": nixArgs }

def _prefetch_package_url(name, url) -> str:
        return subprocess.check_output([
            "nix-prefetch-url",
            url,
            "--unpack",
            "--type",
            "sha256",
            "--name",
            name.replace("/", "-"),
        ],
        encoding="utf-8", stderr=subprocess.DEVNULL).strip()

def _prefetch_git_package(name, package) -> dict:
    desc = package['description']
    out = subprocess.check_output([
        "nix-prefetch-git",
        "--url",
        desc['url'],
        "--rev",
        desc['resolved-ref'] or desc['ref'],
        "--out",
        name.replace("/", "-"),
        ],
        encoding="utf-8", stderr=subprocess.DEVNULL).strip()
    nixArgs = json.loads(out)
    del nixArgs['date'] # reproducibility
    del nixArgs['path'] # alternate store path(?)
    return { "fetcher": "fetchgit", "args": nixArgs }

def _prefetch_package(name, package) -> dict:
    global pbar

    pbar.write(f"Downloading {name}")
    res = {
        "hosted": lambda: _prefetch_hosted_package(
            name, package['description']['url'], package['version']),
        "git": lambda: _prefetch_git_package(name, package)
    }[package["source"]]()

    pbar.update()
    return res

def get_sdk_deps():
    internalDir = join(dirname(str(which('flutter'))), "internal")
    versionFiles = [f for f in listdir(internalDir) if isfile(
        join(internalDir, f)) and f.endswith(".version")]

    versions = {versionFile.removesuffix(".version"): open(
        join(internalDir, versionFile)).read().strip() for versionFile in versionFiles}

    prefix = "https://storage.googleapis.com"

    sdkdeps = {
        "artifacts": {},
        "stamps": { },
    }

    def mk_engine_dep(name: str, cache_path: str | None = None, strip_root: bool = False):
        mk_dep(
            name,
            url=f"{prefix}/flutter_infra_release/flutter/{versions['engine']}/{name}.zip",
            strip_root=strip_root,
            cache_path=cache_path,
        )

    # def mk_ios_usb_dep(name: str):
    #     mk_dep(
    #         name,
    #         url=f"{prefix}/flutter_infra_release/ios-usb-dependencies/{name}/{versions[name]}/{name}.zip",
    #     )

    def mk_dep(name: str, url: str | None = None, strip_root: bool = False, cache_path: str | None = None):
        url = url or f"{prefix}/{versions[name]}"
        sdkdeps["artifacts"][name] = {
            "name": name,
            "url": url,
            "stripRoot": strip_root,
            "cachePath": cache_path or f"artifacts/{name}",
        }

        sdkdeps["artifacts"][name] = _prefetch_package_url(name, url);

    def mk_stamp(name: str, version: str | None = None):
        sdkdeps["stamps"][name] = version or versions[name]

    mk_engine_dep("flutter_patched_sdk",
                  "artifacts/engine/common/flutter_patched_sdk", True)
    mk_engine_dep("flutter_patched_sdk_product",
                  "artifacts/engine/common/flutter_patched_sdk_product", True)
    mk_engine_dep("linux-x64/artifacts", "artifacts/engine/linux-x64")
    mk_engine_dep("linux-x64/font-subset", "artifacts/engine/linux-x64")
    mk_engine_dep("sky_engine", "pkg/sky_engine", True)

    mk_dep("gradle_wrapper")
    mk_dep("material_fonts")

    # mk_ios_usb_dep("ios-deploy")
    # mk_ios_usb_dep("libimobiledevice")
    # mk_ios_usb_dep("libplist")
    # mk_ios_usb_dep("openssl")
    # mk_ios_usb_dep("usbmuxd")

    mk_engine_dep("linux-x64-profile/linux-x64-flutter-gtk",
                  "artifacts/engine/linux-x64-profile")
    mk_engine_dep("linux-x64-release/linux-x64-flutter-gtk",
                  "artifacts/engine/linux-x64-release")
    mk_engine_dep("linux-x64/linux-x64-flutter-gtk",
                  "artifacts/engine/linux-x64")

    mk_stamp("flutter_sdk", versions["engine"])
    mk_stamp("font-subset", versions["engine"])
    mk_stamp("linux-sdk", versions["engine"])
    mk_stamp("gradle_wrapper")
    mk_stamp("material_fonts")

    return sdkdeps


def get_pub(pubspec_lock):
    pub = {}

    for (name, package) in pubspec_lock["packages"].items():
        desc = package['description']

        path = join(
            package['source'],
            desc['url'].removeprefix("https://").replace("/", "%47"),
            f"{name}-{package['version']}"
        )

        pub[path] = _prefetch_package(name, package)


    return pub


def main():
    global pbar
    deps = {}

    pubspec_lock = yaml.safe_load(open("pubspec.lock", "r"))

    pbar = tqdm(total=len({ k: v for k, v in pubspec_lock["packages"].items() if "url" in v["description"] }))

    is_flutter = "flutter" in pubspec_lock["packages"] and pubspec_lock["packages"]["flutter"]["source"] == "sdk" 
    if is_flutter:
        print("Flutter project detected.")

        pbar.total += 10
        deps["sdk"] = get_sdk_deps()
    else:
        print("Dart project detected.")

        pubspec_yaml = yaml.safe_load(open("pubspec.yaml", "r"))

        if pubspec_yaml["executables"]:
            deps["dart"] = {
                "executables": pubspec_yaml["executables"] 
            }
            print("Found executables.")


    deps["pub"] = get_pub(pubspec_lock)

    open("deps2nix.lock", "w").write(json.dumps(
        deps,
        indent=2,
        separators=(',', ': ')
    ))


if __name__ == "__main__":
    main()
