import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

/// RPC response'larından gelen player değişim bilgilerini taşır.
/// Tüm alanlar opsiyoneldir; null gelirse mevcut state korunur.
class PlayerChanges {
  final PlayerModel? fullPlayer;
  final double? cash;
  final double? gold;
  final int? level;
  final int? experience;
  final String? avatarId;
  final String? companyName;
  final String? headquartersCityId;
  final String? headquartersCityName;
  final double? companyValue;
  final int? currentLevelStartExperience;
  final int? nextLevelTotalExperience;
  final int? currentLevelExperience;
  final int? nextLevelRequiredExperience;
  final int? remainingExperienceToNextLevel;
  final double? expProgressRatio;
  final int? achievementUnlockedCount;
  final int? achievementTotalCount;
  final List<AchievementBadgeModel>? featuredBadges;

  const PlayerChanges({
    this.fullPlayer,
    this.cash,
    this.gold,
    this.level,
    this.experience,
    this.avatarId,
    this.companyName,
    this.headquartersCityId,
    this.headquartersCityName,
    this.companyValue,
    this.currentLevelStartExperience,
    this.nextLevelTotalExperience,
    this.currentLevelExperience,
    this.nextLevelRequiredExperience,
    this.remainingExperienceToNextLevel,
    this.expProgressRatio,
    this.achievementUnlockedCount,
    this.achievementTotalCount,
    this.featuredBadges,
  });

  /// RPC response'undaki `changed.player` veya doğrudan `player` bloğundan parse eder.
  factory PlayerChanges.fromJson(Map<String, dynamic> json) {
    PlayerModel? full;
    try {
      if (json['id'] != null) {
        full = PlayerModel.fromJson(json);
      }
    } catch (_) {}

    List<AchievementBadgeModel>? featuredBadges;
    final rawBadges = json['featured_badges'];
    if (rawBadges is List) {
      featuredBadges = rawBadges
          .whereType<Map>()
          .map(
            (item) => AchievementBadgeModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return PlayerChanges(
      fullPlayer: full,
      cash: (json['cash'] as num?)?.toDouble(),
      gold: (json['gold'] as num?)?.toDouble(),
      level: (json['level'] as num?)?.toInt(),
      experience: (json['experience'] as num?)?.toInt(),
      avatarId: json['avatar_id']?.toString(),
      companyName: json['company_name']?.toString(),
      headquartersCityId: json['headquarters_city_id']?.toString(),
      headquartersCityName: json['headquarters_city_name']?.toString(),
      companyValue: (json['company_value'] as num?)?.toDouble(),
      currentLevelStartExperience:
          (json['current_level_start_experience'] as num?)?.toInt(),
      nextLevelTotalExperience:
          (json['next_level_total_experience'] as num?)?.toInt(),
      currentLevelExperience:
          (json['current_level_experience'] as num?)?.toInt(),
      nextLevelRequiredExperience:
          (json['next_level_required_experience'] as num?)?.toInt(),
      remainingExperienceToNextLevel:
          (json['remaining_experience_to_next_level'] as num?)?.toInt(),
      expProgressRatio: (json['exp_progress_ratio'] as num?)?.toDouble(),
      achievementUnlockedCount:
          (json['achievement_unlocked_count'] as num?)?.toInt(),
      achievementTotalCount:
          (json['achievement_total_count'] as num?)?.toInt(),
      featuredBadges: featuredBadges,
    );
  }

  /// RPC response'unun üst bloğundan `changed.player` veya `player` alanını çıkarır.
  static PlayerChanges? tryExtract(Map<String, dynamic> response) {
    final changed = response['changed'];
    if (changed is Map) {
      final playerJson = changed['player'];
      if (playerJson is Map) {
        return PlayerChanges.fromJson(Map<String, dynamic>.from(playerJson));
      }
    }
    final playerJson = response['player'];
    if (playerJson is Map) {
      return PlayerChanges.fromJson(Map<String, dynamic>.from(playerJson));
    }
    return null;
  }
}
