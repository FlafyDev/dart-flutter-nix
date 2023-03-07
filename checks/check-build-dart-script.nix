{buildDartScript, hello}:

buildDartScript "myCoolScript" {
  dependencies = [ hello ];
} ''
  import 'dart:io';

  void main() async {
    final output = await Process.run("hello", []);
    print("Output: " + output.stdout);
  }
''
