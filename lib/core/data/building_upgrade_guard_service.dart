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

  return BuildingUpgradeModel.fromJson(
    Map<String, dynamic>.from(response as Map),
  );
}
