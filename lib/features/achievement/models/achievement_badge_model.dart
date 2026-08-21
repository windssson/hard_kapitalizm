class AchievementBadgeModel {
  final String id;
  final String category;
  final String title;
  final String description;
  final String badgeKey;
  final String badgeColor;
  final int targetCount;
  final int progressCount;
  final bool isUnlocked;
  final bool isClaimed;
  final bool isClaimable;
  final DateTime? unlockedAt;
  final double progressRatio;
  final int rewardXp;
  final double rewardCash;
  final int rewardGold;

  const AchievementBadgeModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.badgeKey,
    required this.badgeColor,
    required this.targetCount,
    required this.progressCount,
    required this.isUnlocked,
    required this.isClaimed,
    required this.isClaimable,
    required this.unlockedAt,
    required this.progressRatio,
    required this.rewardXp,
    required this.rewardCash,
    required this.rewardGold,
  });

  String get compactRewardText {
    final parts = <String>[];
    if (rewardXp > 0) parts.add('+$rewardXp XP');
    if (rewardCash > 0) parts.add('+${rewardCash.toStringAsFixed(0)} Nakit');
    if (rewardGold > 0) parts.add('+$rewardGold Altın');
    return parts.isEmpty ? 'Ödül yok' : parts.join(' | ');
  }

  String get progressText =>
      isUnlocked ? (isClaimed ? 'Kazanıldı' : 'Ödülü Al!') : '$progressCount/$targetCount';

  String get categoryLabel {
    switch (category) {
      case 'expansion':
        return 'Büyüme';
      case 'trade':
        return 'Ticaret';
      case 'logistics':
        return 'Lojistik';
      case 'research':
        return 'Araştırma';
      case 'mastery':
      default:
        return 'Ustalık';
    }
  }

  factory AchievementBadgeModel.fromJson(Map<String, dynamic> json) {
    final rawReward = json['reward'];
    final rewardMap = rawReward is Map<String, dynamic>
        ? rawReward
        : rawReward is Map
            ? Map<String, dynamic>.from(rawReward)
            : const <String, dynamic>{};

    final isUnlocked = json['is_unlocked'] as bool? ?? false;
    final isClaimed = json['is_claimed'] as bool? ?? (json['reward_granted_at'] != null);
    final isClaimable = json['is_claimable'] as bool? ?? (isUnlocked && !isClaimed);

    return AchievementBadgeModel(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? 'mastery').toString(),
      title: (json['title'] ?? 'Başarı').toString(),
      description: (json['description'] ?? '').toString(),
      badgeKey: (json['badge_key'] ?? 'badge').toString(),
      badgeColor: (json['badge_color'] ?? 'gold').toString(),
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      progressCount: (json['progress_count'] as num?)?.toInt() ?? 0,
      isUnlocked: isUnlocked,
      isClaimed: isClaimed,
      isClaimable: isClaimable,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
      progressRatio: (json['progress_ratio'] as num?)?.toDouble() ?? 0,
      rewardXp: (rewardMap['xp'] as num?)?.toInt() ?? 0,
      rewardCash: (rewardMap['cash'] as num?)?.toDouble() ?? 0,
      rewardGold: (rewardMap['gold'] as num?)?.toInt() ?? 0,
    );
  }
}
