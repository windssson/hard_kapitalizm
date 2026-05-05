import 'dart:io';

void main() {
  final file = File('lib/features/home/ui/home_screen.dart');
  var code = file.readAsStringSync();

  code = code.replaceAll('const Divider(', 'Divider(');
  code = code.replaceAll('const Center(', 'Center(');
  code = code.replaceAll('const Column(', 'Column(');
  code = code.replaceAll('const Row(', 'Row(');

  file.writeAsStringSync(code);
}
