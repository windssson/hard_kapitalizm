import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> processProductionEntry({
  required SupabaseClient supabase,
  String? ownerKind,
  String? ownerId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Oturum acilmamis.');
  }

  final response = await supabase.rpc(
    'process_player_production_entry',
    params: {
      'p_player_id': user.id,
      'p_owner_kind': ownerKind,
      'p_owner_id': ownerId,
    },
  );

  if (response == null) {
    return const {'success': true};
  }

  if (response is Map<String, dynamic>) {
    return response;
  }

  if (response is Map) {
    return Map<String, dynamic>.from(response);
  }

  return {'success': true, 'raw': response};
}
