import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';

/// Deliberately limited to fields returned by `get_public_player_profile`.
class PublicPlayerProfileModel {
  final String id;
  final String playerName;
  final String companyName;
  final String avatarId;
  final int level;
  final double expProgressRatio;
  final int currentLevelExperience;
  final int nextLevelRequiredExperience;
  final double companyValue;
  final DateTime createdAt;
  final List<AchievementBadgeModel> featuredBadges;

  const PublicPlayerProfileModel({
    required this.id,
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.level,
    required this.expProgressRatio,
    required this.currentLevelExperience,
    required this.nextLevelRequiredExperience,
    required this.companyValue,
    required this.createdAt,
    required this.featuredBadges,
  });

  factory PublicPlayerProfileModel.fromJson(Map<String, dynamic> json) {
    final badges = (json['featured_badges'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AchievementBadgeModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return PublicPlayerProfileModel(
      id: (json['id'] ?? '').toString(),
      playerName: (json['player_name'] ?? 'Oyuncu').toString(),
      companyName: (json['company_name'] ?? 'Yeni Holding').toString(),
      avatarId: (json['avatar_id'] ?? 'ae1.webp').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      expProgressRatio: (json['exp_progress_ratio'] as num?)?.toDouble() ?? 0,
      currentLevelExperience:
          (json['current_level_experience'] as num?)?.toInt() ?? 0,
      nextLevelRequiredExperience:
          (json['next_level_required_experience'] as num?)?.toInt() ?? 1,
      companyValue: (json['company_value'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      featuredBadges: badges,
    );
  }
}
