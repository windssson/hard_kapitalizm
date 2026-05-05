import 'dart:io';

void main() {
  final file = File('lib/features/home/ui/home_screen.dart');
  var code = file.readAsStringSync();

  // style: Container( -> style: TextStyle(
  code = code.replaceAllMapped(RegExp(r'style:\s*const\s*Container\('), (m) => 'style: const TextStyle(');
  code = code.replaceAllMapped(RegExp(r'style:\s*Container\('), (m) => 'style: TextStyle(');

  // Container(Icons. -> Icon(Icons.
  code = code.replaceAllMapped(RegExp(r'const\s+Container\(\s*Icons\.'), (m) => 'const Icon(Icons.');
  code = code.replaceAllMapped(RegExp(r'Container\(\s*Icons\.'), (m) => 'Icon(Icons.');

  // Extension const issue: .h / .w in const contexts
  code = code.replaceAll(RegExp(r'const\s+EdgeInsets'), 'EdgeInsets');
  code = code.replaceAll(r'const SizedBox(', 'SizedBox(');
  code = code.replaceAll(r'const Icon(', 'Icon(');

  file.writeAsStringSync(code);
}
