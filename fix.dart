import 'dart:io';

void main() {
  final file = File('lib/features/home/ui/home_screen.dart');
  var code = file.readAsStringSync();

  // Fix the \1 replacements
  code = code.replaceAll(r'\1.symmetric', 'EdgeInsets.symmetric');
  code = code.replaceAll(r'\1.all', 'EdgeInsets.all');
  code = code.replaceAll(r'\1.only', 'EdgeInsets.only');
  code = code.replaceAll(r'\1.fromLTRB', 'EdgeInsets.fromLTRB');
  code = code.replaceAll(r'\1.circular', 'BorderRadius.circular');
  code = code.replaceAll(r'\1(width:', 'SizedBox(width:');
  code = code.replaceAll(r'\1(height:', 'SizedBox(height:');
  code = code.replaceAll(r'\1(color:', 'TextStyle(color:');
  code = code.replaceAll(r'\1(Icons.', 'Icon(Icons.');
  code = code.replaceAll(r'\1(padding:', 'Padding(padding:');
  code = code.replaceAll(r'\1(', 'Container('); // Container is the most likely remaining

  file.writeAsStringSync(code);
}
