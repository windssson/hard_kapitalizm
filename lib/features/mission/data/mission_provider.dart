import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final playerMissionDashboardProvider =
    FutureProvider<PlayerMissionDashboardModel>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.rpc('get_player_mission_dashboard');
    return PlayerMissionDashboardModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  } catch (_) {
    return const PlayerMissionDashboardModel(
      success: false,
      mainMission: null,
      dailyMissions: [],
      sideMissions: [],
      claimableCount: 0,
      dailyClaimableCount: 0,
      completedCount: 0,
      dailyCompletedCount: 0,
      totalCount: 0,
    );
  }
});

class MissionActionNotifier {
  final Ref _ref;
  MissionActionNotifier(this._ref);

  Future<Map<String, dynamic>> claimMissionReward(String missionId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'claim_player_mission_reward',
        params: {'p_mission_id': missionId},
      );

      _ref.invalidate(playerMissionDashboardProvider);
      _ref.invalidate(playerProvider);

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final missionActionProvider = Provider<MissionActionNotifier>((ref) {
  return MissionActionNotifier(ref);
});
