import 'dart:io';

void main() {
  final file = File('lib/features/factory/ui/factory_detail_screen.dart');
  final lines = file.readAsLinesSync();
  
  final newLines = <String>[];
  bool skipping = false;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    if (line.contains('Widget _buildHero(FactoryDetailModel detail) {')) {
      skipping = true;
    } else if (skipping && line.contains('Widget _buildInventoryPanel({')) {
      skipping = false;
      newLines.add(line);
    } else if (!skipping) {
      newLines.add(line);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n') + '\n');
}
