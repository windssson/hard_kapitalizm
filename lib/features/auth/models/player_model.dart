import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';

class PlayerModel {
  final String id;
  final String playerName;
  final String companyName;
  final String avatarId;
  final int level;
  final int experience;
  final int currentLevelStartExperience;
  final int nextLevelTotalExperience;
  final int currentLevelExperience;
  final int nextLevelRequiredExperience;
  final int remainingExperienceToNextLevel;
  final double expProgressRatio;
  final int achievementUnlockedCount;
  final int achievementTotalCount;
  final List<AchievementBadgeModel> featuredBadges;
  final double cash;
  final double gold;
  final DateTime createdAt;

  PlayerModel({
    required this.id,
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.level,
    required this.experience,
    required this.currentLevelStartExperience,
    required this.nextLevelTotalExperience,
    required this.currentLevelExperience,
    required this.nextLevelRequiredExperience,
    required this.remainingExperienceToNextLevel,
    required this.expProgressRatio,
    required this.achievementUnlockedCount,
    required this.achievementTotalCount,
    required this.featuredBadges,
    required this.cash,
    required this.gold,
    required this.createdAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    final rawBadges = (json['featured_badges'] as List?) ?? const [];

    return PlayerModel(
      id: json['id'] as String,
      playerName: json['player_name'] as String? ?? 'Oyuncu',
      companyName: json['company_name'] as String? ?? 'Yeni Holding',
      avatarId: json['avatar_id'] as String? ?? 'avatar_1.webp',
      level: json['level'] as int? ?? 1,
      experience: json['experience'] as int? ?? 0,
      currentLevelStartExperience:
          (json['current_level_start_experience'] as num?)?.toInt() ?? 0,
      nextLevelTotalExperience:
          (json['next_level_total_experience'] as num?)?.toInt() ??
          (json['experience'] as int? ?? 0),
      currentLevelExperience:
          (json['current_level_experience'] as num?)?.toInt() ??
          (json['experience'] as int? ?? 0),
      nextLevelRequiredExperience:
          (json['next_level_required_experience'] as num?)?.toInt() ?? 1,
      remainingExperienceToNextLevel:
          (json['remaining_experience_to_next_level'] as num?)?.toInt() ?? 0,
      expProgressRatio: (json['exp_progress_ratio'] as num?)?.toDouble() ?? 0,
      achievementUnlockedCount:
          (json['achievement_unlocked_count'] as num?)?.toInt() ?? 0,
      achievementTotalCount:
          (json['achievement_total_count'] as num?)?.toInt() ?? 0,
      featuredBadges: rawBadges
          .map(
            (item) => AchievementBadgeModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      cash: (json['cash'] as num?)?.toDouble() ?? 100000.0,
      gold: (json['gold'] as num?)?.toDouble() ?? 100.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_name': playerName,
      'company_name': companyName,
      'avatar_id': avatarId,
      'level': level,
      'experience': experience,
      'current_level_start_experience': currentLevelStartExperience,
      'next_level_total_experience': nextLevelTotalExperience,
      'current_level_experience': currentLevelExperience,
      'next_level_required_experience': nextLevelRequiredExperience,
      'remaining_experience_to_next_level': remainingExperienceToNextLevel,
      'exp_progress_ratio': expProgressRatio,
      'achievement_unlocked_count': achievementUnlockedCount,
      'achievement_total_count': achievementTotalCount,
      'featured_badges': featuredBadges
          .map(
            (badge) => {
              'id': badge.id,
              'category': badge.category,
              'title': badge.title,
              'description': badge.description,
              'badge_key': badge.badgeKey,
              'badge_color': badge.badgeColor,
              'target_count': badge.targetCount,
              'progress_count': badge.progressCount,
              'is_unlocked': badge.isUnlocked,
              'unlocked_at': badge.unlockedAt?.toIso8601String(),
              'progress_ratio': badge.progressRatio,
              'reward': {
                'xp': badge.rewardXp,
                'cash': badge.rewardCash,
                'gold': badge.rewardGold,
              },
            },
          )
          .toList(),
      'cash': cash,
      'gold': gold,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
