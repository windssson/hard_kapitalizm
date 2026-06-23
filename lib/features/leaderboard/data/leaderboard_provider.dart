import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/leaderboard/models/leaderboard_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntryModel>, String>((ref, sortByField) async {
  final supabase = Supabase.instance.client;
  
  // Call the refresh RPC for the current player first, to ensure up-to-date stats
  final user = supabase.auth.currentUser;
  if (user != null) {
    try {
      await supabase.rpc('refresh_player_leaderboard_stats', params: {'p_player_id': user.id});
    } catch (_) {
      // Ignore background refresh errors
    }
  }

  final response = await supabase
      .from('player_leaderboard_stats')
      .select()
      .order(sortByField, ascending: false)
      .limit(100);

  final rows = response as List<dynamic>? ?? const [];
  return rows.map((row) => LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(row as Map))).toList();
});

class PlayerRankInfo {
  final int rank;
  final LeaderboardEntryModel? entry;

  PlayerRankInfo({required this.rank, required this.entry});
}

final currentPlayerRankProvider = FutureProvider.family<PlayerRankInfo?, String>((ref, sortByField) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  // Let's first check if current player is in top 100 leaderboard list
  final leaderboardList = ref.watch(leaderboardProvider(sortByField)).value ?? [];
  
  final topIdx = leaderboardList.indexWhere((element) => element.playerId == user.id);
  if (topIdx != -1) {
    return PlayerRankInfo(
      rank: topIdx + 1,
      entry: leaderboardList[topIdx],
    );
  }

  // If not in top 100, fetch the player's entry from leaderboard stats
  final entryResponse = await supabase
      .from('player_leaderboard_stats')
      .select()
      .eq('player_id', user.id)
      .maybeSingle();

  if (entryResponse == null) {
    return null;
  }

  final entry = LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(entryResponse as Map));

  // Count how many players have a strictly greater value
  final metricValue = entryResponse[sortByField];
  if (metricValue == null) {
    return PlayerRankInfo(rank: 999, entry: entry);
  }

  final countResponse = await supabase
      .from('player_leaderboard_stats')
      .select('player_id')
      .gt(sortByField, metricValue);

  final count = (countResponse as List<dynamic>).length;

  return PlayerRankInfo(
    rank: count + 1,
    entry: entry,
  );
});
