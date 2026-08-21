import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';

class PlayerModel {
  final String id;
  final String playerName;
  final String companyName;
  final String avatarId;
  final String? googleAvatarUrl;
  final String? headquartersCityId;
  final String? headquartersCityName;
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
  final double companyValue;
  final DateTime createdAt;

  PlayerModel({
    required this.id,
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.googleAvatarUrl,
    this.headquartersCityId,
    this.headquartersCityName,
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
    required this.companyValue,
    required this.createdAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    final rawBadges = (json['featured_badges'] as List?) ?? const [];

    return PlayerModel(
      id: (json['id'] ?? '').toString(),
      playerName: (json['player_name'] ?? 'Oyuncu').toString(),
      companyName: (json['company_name'] ?? 'Yeni Holding').toString(),
      avatarId: (json['avatar_id'] ?? 'ae1.webp').toString(),
      googleAvatarUrl: json['google_avatar_url']?.toString(),
      headquartersCityId: json['headquarters_city_id']?.toString(),
      headquartersCityName: json['headquarters_city_name']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      currentLevelStartExperience:
          (json['current_level_start_experience'] as num?)?.toInt() ?? 0,
      nextLevelTotalExperience:
          (json['next_level_total_experience'] as num?)?.toInt() ??
          ((json['experience'] as num?)?.toInt() ?? 0),
      currentLevelExperience:
          (json['current_level_experience'] as num?)?.toInt() ??
          ((json['experience'] as num?)?.toInt() ?? 0),
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
      companyValue: (json['company_value'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  PlayerModel copyWith({
    String? id,
    String? playerName,
    String? companyName,
    String? avatarId,
    String? googleAvatarUrl,
    String? headquartersCityId,
    String? headquartersCityName,
    int? level,
    int? experience,
    int? currentLevelStartExperience,
    int? nextLevelTotalExperience,
    int? currentLevelExperience,
    int? nextLevelRequiredExperience,
    int? remainingExperienceToNextLevel,
    double? expProgressRatio,
    int? achievementUnlockedCount,
    int? achievementTotalCount,
    List<AchievementBadgeModel>? featuredBadges,
    double? cash,
    double? gold,
    double? companyValue,
    DateTime? createdAt,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      playerName: playerName ?? this.playerName,
      companyName: companyName ?? this.companyName,
      avatarId: avatarId ?? this.avatarId,
      googleAvatarUrl: googleAvatarUrl ?? this.googleAvatarUrl,
      headquartersCityId: headquartersCityId ?? this.headquartersCityId,
      headquartersCityName: headquartersCityName ?? this.headquartersCityName,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      currentLevelStartExperience:
          currentLevelStartExperience ?? this.currentLevelStartExperience,
      nextLevelTotalExperience:
          nextLevelTotalExperience ?? this.nextLevelTotalExperience,
      currentLevelExperience:
          currentLevelExperience ?? this.currentLevelExperience,
      nextLevelRequiredExperience:
          nextLevelRequiredExperience ?? this.nextLevelRequiredExperience,
      remainingExperienceToNextLevel:
          remainingExperienceToNextLevel ?? this.remainingExperienceToNextLevel,
      expProgressRatio: expProgressRatio ?? this.expProgressRatio,
      achievementUnlockedCount:
          achievementUnlockedCount ?? this.achievementUnlockedCount,
      achievementTotalCount:
          achievementTotalCount ?? this.achievementTotalCount,
      featuredBadges: featuredBadges ?? this.featuredBadges,
      cash: cash ?? this.cash,
      gold: gold ?? this.gold,
      companyValue: companyValue ?? this.companyValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_name': playerName,
      'company_name': companyName,
      'avatar_id': avatarId,
      'google_avatar_url': googleAvatarUrl,
      'headquarters_city_id': headquartersCityId,
      'headquarters_city_name': headquartersCityName,
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
      'company_value': companyValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
