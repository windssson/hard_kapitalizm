import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> processProductionEntry({
  required SupabaseClient supabase,
  String? ownerKind,
  String? ownerId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Oturum acilmamis.');
  }

  await supabase.rpc(
    'process_player_production_entry',
    params: {
      'p_player_id': user.id,
      'p_owner_kind': ownerKind,
      'p_owner_id': ownerId,
    },
  );
}
