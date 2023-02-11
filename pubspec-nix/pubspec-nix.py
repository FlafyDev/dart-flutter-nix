from os import listdir
from os.path import isfile, join, dirname
from posixpath import join as urljoin
from shutil import which
import subprocess
import json
import yaml
from tqdm import tqdm
import logging
import argparse

pbar: tqdm
log = logging.getLogger(__name__)

parser = argparse.ArgumentParser(
                    prog = 'pubspec-nix',
                    description = 'Generate pubspec-nix.lock from pubspec.yaml')

parser.add_argument('--hash', default=True, action=argparse.BooleanOptionalAction)
args = parser.parse_args();

def _prefetch_hosted_package(name, package) -> tuple[str, dict]:
    version = package['version']
    base_url = package['description']['url']
    url = urljoin(
        base_url,
        "packages",
        name,
        "versions",
        f"{version}.tar.gz",
    )

    nixArgs = {
        "name": f"pub-{name}-{version}",
        "url": url,
        "stripRoot": False,
    }

    if args.hash:
        nixArgs["sha256"] = _prefetch_package_url(
            name,
            url,
        )

    path = join(
        package['source'],
        package['description']['url'].removeprefix("https://").replace("/", "%47"),
        f"{name}-{package['version']}"
    )
    return path, { "fetcher": "fetchzip", "args": nixArgs }

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

def _prefetch_git_package(name, package) -> tuple[str, dict]:
    desc = package['description']
    out = subprocess.check_output([
        "nix-prefetch-git",
        "--url",
        desc['url'],
        "--rev",
        desc['resolved-ref'] or desc['ref'],
        "--out",
        name.replace("/", "-"),
        "--leave-dotGit"
        ],
        encoding="utf-8", stderr=subprocess.DEVNULL).strip()
    nixArgs = json.loads(out)
    del nixArgs['date'] # reproducibility
    del nixArgs['path'] # alternate store path(?)
    repo_name = desc['url'].split("/")[-1]
    if (repo_name.endswith(".git")):
        repo_name = repo_name.removesuffix(".git")
    path = join(
        package['source'],
        f"{repo_name}-{nixArgs['rev']}",
    )
    return path, { "fetcher": "fetchgit", "args": nixArgs, "repo_name": repo_name }

def _prefetch_package(name, package, pub) -> None:
    res = {
        "hosted": lambda: _prefetch_hosted_package(name, package),
        "git": lambda: _prefetch_git_package(name, package)
    }.get(package["source"])
    
    if res:
        path, value = res()
        pub[path] = value


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
        global pbar

        pbar.write(f"Downloading {name}");

        url = url or f"{prefix}/{versions[name]}"
        sdkdeps["artifacts"][name] = {
            "name": name,
            "url": url,
            "stripRoot": strip_root,
            "cachePath": cache_path or f"artifacts/{name}",
        }

        if args.hash:
            sdkdeps["artifacts"][name]["sha256"] = _prefetch_package_url(name, url);

        pbar.update()

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


def get_pub(packages):
    global pbar

    pub = {}

    for (name, package) in packages.items():
        pbar.write(f"Processing package {name}")

        _prefetch_package(name, package, pub)

        pbar.update()

    return pub


def main():
    global pbar
    deps = {}

    pubspec_lock = yaml.safe_load(open("pubspec.lock", "r"))
    packages = pubspec_lock["packages"]

    pbar = tqdm(total=len(packages))

    is_flutter = "flutter" in packages and packages["flutter"]["source"] == "sdk" 
    if is_flutter:
        pbar.write("Flutter project detected.")

        pbar.total += 10
        deps["sdk"] = get_sdk_deps()
    else:
        pbar.write("Dart project detected.")

        pubspec_yaml = yaml.safe_load(open("pubspec.yaml", "r"))

        deps["dart"] = {
            "executables": pubspec_yaml.get("executables", {})
        }

    deps["pub"] = get_pub(packages)

    open("pubspec-nix.lock", "w").write(json.dumps(
        deps,
        indent=2,
        separators=(',', ': ')
    ))


if __name__ == "__main__":
    main()
