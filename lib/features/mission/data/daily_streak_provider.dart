import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        final res = await supabase.rpc('get_player_daily_streak');
        if (res is Map) {
          final streakCount = (res['streak_count'] as num?)?.toInt() ?? 0;
          final canClaimToday = (res['can_claim_today'] as bool?) ?? true;
          final lastClaimedStr = res['last_claimed_at'] as String? ?? res['last_claimed_date'] as String?;
          final lastClaimedDate = lastClaimedStr != null ? DateTime.tryParse(lastClaimedStr) : null;

          return DailyStreakData(
            streakCount: streakCount,
            lastClaimedDate: lastClaimedDate,
            canClaimToday: canClaimToday,
          );
        }
      } catch (_) {}
    }

    // Yerel önbellek yedeği
    final prefs = await SharedPreferences.getInstance();
    final streakCount = prefs.getInt(_streakCountKey) ?? 0;
    final lastClaimedStr = prefs.getString(_lastClaimedKey);
    final lastClaimedDate = lastClaimedStr != null ? DateTime.tryParse(lastClaimedStr) : null;

    final canClaimToday = _checkCanClaimToday(lastClaimedDate);

    return DailyStreakData(
      streakCount: streakCount,
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

    try {
      // K03: Ödül tutarları sunucu tarafında belirlenir, parametresiz çağrılır
      final response = await supabase.rpc('claim_daily_streak_reward');
      if (response == null) return false;

      final resMap = Map<String, dynamic>.from(response as Map);
      ref.read(mutationSyncServiceProvider).applyRaw(resMap);

      final nextStreak = (resMap['streak_count'] as num?)?.toInt() ?? (current.streakCount + 1);
      final now = DateTime.now();

      // Yerel önbelleği güncelle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_streakCountKey, nextStreak);
      await prefs.setString(_lastClaimedKey, now.toIso8601String());

      state = AsyncData(DailyStreakData(
        streakCount: nextStreak,
        lastClaimedDate: now,
        canClaimToday: false,
      ));

      return true;
    } catch (e) {
      return false;
    }
  }
}

final dailyStreakProvider =
    AsyncNotifierProvider<DailyStreakNotifier, DailyStreakData>(() {
  return DailyStreakNotifier();
});

