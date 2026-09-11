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

/// Legacy compatibility shim.
///
/// Natural timed upgrade completion is exclusively owned by TimedTaskRuntime.
/// Feature screens/providers may still call this method while the old surface
/// API is being cleaned up, but it must never issue a completion RPC.
@Deprecated('TimedTaskRuntime owns natural building-upgrade completion.')
Future<void> tryCompleteDueBuildingUpgrades(
  SupabaseClient supabase,
) async {
  return;
}
