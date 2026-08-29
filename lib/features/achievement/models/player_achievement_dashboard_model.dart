import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';

class PlayerAchievementDashboardModel {
  final bool success;
  final List<AchievementBadgeModel> featuredBadges;
  final List<AchievementBadgeModel> activeAchievements;
  final List<AchievementBadgeModel> unlockedAchievements;
  final int unlockedCount;
  final int claimableCount;
  final int totalCount;

  const PlayerAchievementDashboardModel({
    required this.success,
    required this.featuredBadges,
    required this.activeAchievements,
    required this.unlockedAchievements,
    required this.unlockedCount,
    required this.claimableCount,
    required this.totalCount,
  });

  factory PlayerAchievementDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawFeatured = (json['featured_badges'] as List?) ?? const [];
    final rawActive = (json['active_achievements'] as List?) ?? const [];
    final rawUnlocked = (json['unlocked_achievements'] as List?) ?? const [];
    final rawSummary = json['summary'];
    final summary = rawSummary is Map<String, dynamic>
        ? rawSummary
        : rawSummary is Map
            ? Map<String, dynamic>.from(rawSummary)
            : const <String, dynamic>{};

    return PlayerAchievementDashboardModel(
      success: json['success'] as bool? ?? false,
      featuredBadges: rawFeatured
          .map(
            (item) => AchievementBadgeModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      activeAchievements: rawActive
          .map(
            (item) => AchievementBadgeModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      unlockedAchievements: rawUnlocked
          .map(
            (item) => AchievementBadgeModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      unlockedCount: (summary['unlocked_count'] as num?)?.toInt() ?? 0,
      claimableCount: (summary['claimable_count'] as num?)?.toInt() ?? 0,
      totalCount: (summary['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  PlayerAchievementDashboardModel copyWith({
    bool? success,
    List<AchievementBadgeModel>? featuredBadges,
    List<AchievementBadgeModel>? activeAchievements,
    List<AchievementBadgeModel>? unlockedAchievements,
    int? unlockedCount,
    int? claimableCount,
    int? totalCount,
  }) {
    return PlayerAchievementDashboardModel(
      success: success ?? this.success,
      featuredBadges: featuredBadges ?? this.featuredBadges,
      activeAchievements: activeAchievements ?? this.activeAchievements,
      unlockedAchievements:
          unlockedAchievements ?? this.unlockedAchievements,
      unlockedCount: unlockedCount ?? this.unlockedCount,
      claimableCount: claimableCount ?? this.claimableCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
