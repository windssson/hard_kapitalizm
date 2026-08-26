import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/leaderboard/models/leaderboard_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardQuery {
  final String sortByField;
  final String? cityId;

  const LeaderboardQuery({
    required this.sortByField,
    this.cityId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardQuery &&
          runtimeType == other.runtimeType &&
          sortByField == other.sortByField &&
          cityId == other.cityId;

  @override
  int get hashCode => sortByField.hashCode ^ (cityId?.hashCode ?? 0);
}

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntryModel>, LeaderboardQuery>((ref, query) async {
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

  try {
    final response = await supabase.rpc(
      'get_leaderboard',
      params: {
        'p_sort_by_field': query.sortByField,
        'p_limit': 100,
        if (query.cityId != null) 'p_city_id': query.cityId,
      },
    );

    final rows = response as List<dynamic>? ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  } catch (e) {
    return const [];
  }
});

class PlayerRankInfo {
  final int rank;
  final LeaderboardEntryModel? entry;

  PlayerRankInfo({required this.rank, required this.entry});
}

final currentPlayerRankProvider = FutureProvider.family<PlayerRankInfo?, LeaderboardQuery>((ref, query) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  // Let's first check if current player is in top 100 leaderboard list
  final leaderboardList = ref.watch(leaderboardProvider(query)).value ?? [];
  
  final topIdx = leaderboardList.indexWhere((element) => element.playerId == user.id);
  if (topIdx != -1) {
    return PlayerRankInfo(
      rank: topIdx + 1,
      entry: leaderboardList[topIdx],
    );
  }

  try {
    // Fetch the player's rank and entry data via unified RPC:
    final response = await supabase.rpc(
      'get_player_leaderboard_rank_info',
      params: {
        'p_player_id': user.id,
        'p_sort_by_field': query.sortByField,
        if (query.cityId != null) 'p_city_id': query.cityId,
      },
    );

    if (response == null) return null;

    final responseMap = Map<String, dynamic>.from(response as Map);
    final entryMap = responseMap['entry'];
    if (entryMap == null) return null;

    return PlayerRankInfo(
      rank: (responseMap['rank'] as num).toInt(),
      entry: LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(entryMap as Map)),
    );
  } catch (_) {
    return null;
  }
});

