// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://lpiixtfxldhoyyppavyn.supabase.co/rest/v1';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwaWl4dGZ4bGRob3l5cHBhdnluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwMTM4ODYsImV4cCI6MjA5MzU4OTg4Nn0.FgppoUpi5EQO4SSCwZWpd6YpHND1RNFwW3zEjStgI2c';

  final client = HttpClient();

  Future<void> queryTable(String tableName, String queryParams) async {
    try {
      final request = await client.getUrl(Uri.parse('$url/$tableName?$queryParams'));
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $anonKey');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      print('=== Table: $tableName ($queryParams) ===');
      print(responseBody);
    } catch (e) {
      print('Error querying $tableName: $e');
    }
  }

  await queryTable('production_slots', 'select=*&limit=5');
  await queryTable('factories', 'select=*&limit=5');
  await queryTable('farms', 'select=*&limit=5');
  await queryTable('fields', 'select=*&limit=5');
  await queryTable('mines', 'select=*&limit=5');

  client.close();
}
