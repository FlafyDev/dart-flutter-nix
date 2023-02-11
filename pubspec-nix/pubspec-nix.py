from os.path import join
from posixpath import join as urljoin
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


def _get_pub(packages):
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
    else:
        pbar.write("Dart project detected.")

        pubspec_yaml = yaml.safe_load(open("pubspec.yaml", "r"))

        deps["dart"] = {
            "executables": pubspec_yaml.get("executables", {})
        }

    deps["pub"] = _get_pub(packages)

    open("pubspec-nix.lock", "w").write(json.dumps(
        deps,
        indent=2,
        separators=(',', ': ')
    ))


if __name__ == "__main__":
    main()
