import 'dart:io';

void main() {
  final file = File('c:/Proje/hard_kapitalizm/database_schema.sql');
  final content = file.readAsStringSync();
  
  final functionNames = [
    'get_transfer_vehicle_options',
    'get_market_transfer_vehicle_options',
    'get_market_transfer_vehicle_options_for_store',
    'start_market_to_store_transfer',
    'start_market_transfer',
    'start_production_to_warehouse_transfer',
    'start_store_to_warehouse_transfer',
    'start_warehouse_to_warehouse_transfer',
    'start_warehouse_to_production_transfer',
    'start_warehouse_to_store_transfer'
  ];
  
  for (var name in functionNames) {
    // Find the function body
    final startIdx = content.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
    if (startIdx == -1) {
      print('$name: NOT FOUND');
      continue;
    }
    
    // Find the end of the function
    final endIdx = content.indexOf(r'$function$', startIdx);
    if (endIdx == -1) {
      print('$name: END NOT FOUND');
      continue;
    }
    
    final funcBody = content.substring(startIdx, endIdx + 11);
    
    // Count occurrences of 00000000
    final matches = '00000000-0000-0000-0000-000000000000'.allMatches(funcBody).length;
    
    // Check for ambiguous can_select
    final ambiguous = RegExp(r'order by.*(?<!t\.)can_select desc').hasMatch(funcBody);
    
    print('$name: NPC Patches: $matches, Ambiguous can_select: $ambiguous');
  }
}
