import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<BuildingUpgradeModel?> fetchAnyActiveBuildingUpgrade(
  SupabaseClient supabase,
) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    return null;
  }

  final response = await supabase.rpc('get_player_any_active_building_upgrade');
  if (response == null) {
    return null;
  }

  return BuildingUpgradeModel.fromJsonNullable(
    Map<String, dynamic>.from(response as Map),
  );
}

Future<void> tryCompleteDueBuildingUpgrades(
  SupabaseClient supabase,
) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final response = await supabase.rpc(
    'complete_due_player_building_upgrades',
    params: {
      'p_player_id': user.id,
      'p_limit': 100,
      'p_building_kind': null,
      'p_entity_id': null,
    },
  );

  final result = Map<String, dynamic>.from(response as Map);
  final failedCount = (result['failed_count'] as num?)?.toInt() ?? 0;
  if (result['success'] != true || failedCount > 0) {
    throw Exception(
      'Suresi dolan bina yukseltmeleri tamamlanamadi '
      '(failed_count: $failedCount).',
    );
  }
}
