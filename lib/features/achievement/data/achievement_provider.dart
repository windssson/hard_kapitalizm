import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/achievement/models/player_achievement_dashboard_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final playerAchievementDashboardProvider =
    FutureProvider<PlayerAchievementDashboardModel>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_player_achievement_dashboard');
  return PlayerAchievementDashboardModel.fromJson(
    Map<String, dynamic>.from(response as Map),
  );
});

final achievementActionProvider = Provider((ref) => AchievementActionService(ref));

class AchievementActionService {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  AchievementActionService(this._ref);

  Future<Map<String, dynamic>> claimAchievementReward(String achievementId) async {
    final response = await _supabase.rpc(
      'claim_player_achievement_reward',
      params: {'p_achievement_id': achievementId},
    );

    final resultMap = response is Map<String, dynamic>
        ? response
        : response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{'success': false};

    // Refresh dashboards
    _ref.invalidate(playerAchievementDashboardProvider);
    _ref.invalidate(playerProvider);
    _ref.invalidate(homeDashboardProvider);

    return resultMap;
  }
}
