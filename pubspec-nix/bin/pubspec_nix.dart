import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart' as yaml;

const utf8 = Utf8Codec();
const jsonEncoder = JsonEncoder.withIndent('  ');

Future<Map> parseYamlFile(String filePath) async {
  final fileRaw = await File(filePath).readAsString();
  return yaml.loadYaml(fileRaw, sourceUrl: Uri.file(filePath));
}

Future<Map> prefetchGit(
  String name, {
  required Map desc,
  required String baseUrl,
  required String cleanName,
}) async {
  var proc = await Process.run(
      "nix-prefetch-git",
      [
        "--url",
        baseUrl,
        "--rev",
        desc['resolved-ref'] ?? desc['ref'],
        "--out",
        cleanName,
        "--leave-dotGit"
      ],
      stdoutEncoding: utf8);
  Map parsed = json.decode((proc.stdout as String).trim());
  parsed.remove('date');
  parsed.remove('path');

  final repoName = desc['url'].split('/').last.replaceAll(".git", "");
  return {
    "git/$repoName-${parsed['rev']}": {
      "fetcher": "fetchgit",
      "args": parsed,
      "repo_name": repoName,
    }
  };
}

Future<Map> prefetchPub({
  required Map package,
  required String baseUrl,
  required String name,
  required String cleanName,
}) async {
  final version = package['version'];
  String url = "$baseUrl/packages/$name/versions/$version.tar.gz";
  Future<String> prefetchUrl() async {
    var proc = await Process.run("nix-prefetch-url",
        [url, "--unpack", "--type", "sha256", "--name", cleanName],
        stdoutEncoding: utf8);
    return (proc.stdout as String).trim();
  }

  final fetcherArgs = {
    "name": "pub-$name-$version",
    "url": url,
    "stripRoot": false,
    "sha256": (await prefetchUrl())
  };

  //  TODO also handle http
  final keyPath =
      "hosted/${baseUrl.replaceFirst(RegExp(r'(http|https)://'), "").replaceAll('/', "%47")}/$name-$version";
  return {
    keyPath: {"fetcher": "fetchzip", "args": fetcherArgs}
  };
}

Future<Map> prefetchSinglePackage(String name, Map package) async {
  Map desc = package["description"];
  String baseUrl = desc["url"];
  final cleanName = name.replaceAll("/", "-");

  switch (package["source"]) {
    case "hosted":
      return await prefetchPub(
          cleanName: cleanName, baseUrl: baseUrl, name: name, package: package);
    case "git":
      return await prefetchGit(name,
          baseUrl: baseUrl, cleanName: cleanName, desc: desc);
    default:
      throw "Unsupported package source: ${package["source"]}";
  }
}

Future<Map> getFromPub(Map packages) async {
  var res = {};
  final kLen = packages.keys.length;
  var toProcess = List.generate(kLen, (index) {
    final key = packages.keys.elementAt(index);

    print("processing $key (${index + 1}/$kLen)");
    return prefetchSinglePackage(key, packages[key]);
  });
  var processed = await Future.wait(toProcess);
  for (var element in processed) {
    res.addAll(element);
  }

  return res;
}

void main(List<String> arguments) async {
  final pubspecLock = await parseYamlFile("pubspec.lock");
  Map packages = pubspecLock["packages"];
  var deps = {};

  var isFlutter =
      packages.containsKey("flutter") && packages["flutter"]["source"] == "sdk";

  if (!isFlutter) {
    print("Dart project detected");
    Map pubspecYaml = await parseYamlFile("pubspec.yaml");
    deps["dart"] = {
      "executables": pubspecYaml["executables"] ?? {},
    };
  } else {
    print("Flutter project detected");
  }

  deps["pub"] = await getFromPub(packages);
  print("Writing json to file");
  File('pubspec-nix.lock').writeAsString(jsonEncoder.convert(deps));
}
