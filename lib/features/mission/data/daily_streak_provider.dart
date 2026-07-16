import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

class DailyStreakData {
  final int streakCount; // 0 to 7
  final DateTime? lastClaimedDate;
  final bool canClaimToday;

  const DailyStreakData({
    required this.streakCount,
    this.lastClaimedDate,
    required this.canClaimToday,
  });

  DailyStreakData copyWith({
    int? streakCount,
    DateTime? lastClaimedDate,
    bool? canClaimToday,
  }) {
    return DailyStreakData(
      streakCount: streakCount ?? this.streakCount,
      lastClaimedDate: lastClaimedDate ?? this.lastClaimedDate,
      canClaimToday: canClaimToday ?? this.canClaimToday,
    );
  }
}

class DailyStreakNotifier extends AsyncNotifier<DailyStreakData> {
  static const _streakCountKey = 'daily_streak_count';
  static const _lastClaimedKey = 'daily_streak_last_claimed';

  @override
  Future<DailyStreakData> build() async {
    final prefs = await SharedPreferences.getInstance();
    final streakCount = prefs.getInt(_streakCountKey) ?? 0;
    final lastClaimedStr = prefs.getString(_lastClaimedKey);
    final lastClaimedDate = lastClaimedStr != null ? DateTime.parse(lastClaimedStr) : null;

    final canClaimToday = _checkCanClaimToday(lastClaimedDate);
    
    // Check if streak was broken:
    int activeStreakCount = streakCount;
    if (lastClaimedDate != null && streakCount > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final claimedDay = DateTime(lastClaimedDate.year, lastClaimedDate.month, lastClaimedDate.day);
      final diffDays = today.difference(claimedDay).inDays;
      
      if (diffDays > 1) {
        // Reset streak!
        activeStreakCount = 0;
        await prefs.setInt(_streakCountKey, 0);
      }
    }

    return DailyStreakData(
      streakCount: activeStreakCount,
      lastClaimedDate: lastClaimedDate,
      canClaimToday: canClaimToday,
    );
  }

  bool _checkCanClaimToday(DateTime? lastClaimed) {
    if (lastClaimed == null) return true;
    final now = DateTime.now();
    return !(lastClaimed.year == now.year &&
        lastClaimed.month == now.month &&
        lastClaimed.day == now.day);
  }

  Future<bool> claimReward() async {
    final current = state.value;
    if (current == null || !current.canClaimToday) return false;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Fetch latest player profile:
    final response = await supabase.rpc(
      'get_player_profile',
      params: {'p_player_id': user.id},
    );
    if (response == null) return false;

    final player = PlayerModel.fromJson(Map<String, dynamic>.from(response as Map));

    // Determine rewards:
    double rewardCash = 0;
    double rewardGold = 0;
    int nextStreakCount = current.streakCount + 1;
    if (nextStreakCount > 7) {
      nextStreakCount = 1; // start new cycle
    }

    switch (nextStreakCount) {
      case 1:
        rewardCash = 10000;
        break;
      case 2:
        rewardCash = 25000;
        break;
      case 3:
        rewardGold = 5;
        break;
      case 4:
        rewardCash = 50000;
        break;
      case 5:
        rewardGold = 10;
        break;
      case 6:
        rewardCash = 100000;
        break;
      case 7:
        rewardGold = 50;
        break;
    }

    final nextCash = player.cash + rewardCash;
    final nextGold = player.gold + rewardGold;

    // Update in database:
    await supabase
        .from('players')
        .update({'cash': nextCash, 'gold': nextGold})
        .eq('id', user.id);

    // Save locally:
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_streakCountKey, nextStreakCount);
    await prefs.setString(_lastClaimedKey, now.toIso8601String());

    // Refresh state:
    state = AsyncData(DailyStreakData(
      streakCount: nextStreakCount,
      lastClaimedDate: now,
      canClaimToday: false,
    ));

    // Invalidate player so cash/gold top bar updates:
    ref.invalidate(playerProvider);

    return true;
  }
}

final dailyStreakProvider =
    AsyncNotifierProvider<DailyStreakNotifier, DailyStreakData>(() {
  return DailyStreakNotifier();
});
