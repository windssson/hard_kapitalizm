import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/achievement/models/player_achievement_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final playerAchievementDashboardProvider =
    FutureProvider<PlayerAchievementDashboardModel>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_player_achievement_dashboard');
  return PlayerAchievementDashboardModel.fromJson(
    Map<String, dynamic>.from(response as Map),
  );
});
