import 'package:hard_kapitalizm/features/mission/models/mission_reward_model.dart';

class PlayerMissionModel {
  final String id;
  final String missionType;
  final String title;
  final String description;
  final String eventKey;
  final String? iconKey;
  final int targetCount;
  final int progressCount;
  final bool isCompleted;
  final bool isClaimed;
  final bool claimable;
  final MissionRewardModel reward;
  final int displayOrder;
  final double progressRatio;

  const PlayerMissionModel({
    required this.id,
    required this.missionType,
    required this.title,
    required this.description,
    required this.eventKey,
    required this.iconKey,
    required this.targetCount,
    required this.progressCount,
    required this.isCompleted,
    required this.isClaimed,
    required this.claimable,
    required this.reward,
    required this.displayOrder,
    required this.progressRatio,
  });

  bool get isInProgress => !isClaimed && !isCompleted;

  String get compactRewardText {
    final parts = <String>[];
    if (reward.xp > 0) parts.add('+${reward.xp} XP');
    if (reward.cash > 0) parts.add('+${reward.cash.toStringAsFixed(0)} Nakit');
    if (reward.gold > 0) parts.add('+${reward.gold} Altin');
    return parts.isEmpty ? 'Odul yok' : parts.join(' | ');
  }

  String get compactStatusText {
    if (claimable) return 'Odul Hazir | $compactRewardText';
    if (isClaimed) return 'Tamamlandi';
    return '$progressCount/$targetCount | $compactRewardText';
  }

  String get missionTypeLabel {
    switch (missionType) {
      case 'main':
        return 'Ana Gorev';
      case 'side':
        return 'Yan Gorev';
      case 'achievement':
        return 'Basari';
      case 'daily':
        return 'Gunluk Gorev';
      default:
        return 'Gorev';
    }
  }

  factory PlayerMissionModel.fromJson(Map<String, dynamic> json) {
    final rawReward = json['reward'];
    return PlayerMissionModel(
      id: (json['id'] ?? '').toString(),
      missionType: (json['mission_type'] ?? 'side').toString(),
      title: (json['title'] ?? 'Gorev').toString(),
      description: (json['description'] ?? '').toString(),
      eventKey: (json['event_key'] ?? '').toString(),
      iconKey: json['icon_key']?.toString(),
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      progressCount: (json['progress_count'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      isClaimed: json['is_claimed'] as bool? ?? false,
      claimable: json['claimable'] as bool? ?? false,
      reward: rawReward is Map<String, dynamic>
          ? MissionRewardModel.fromJson(rawReward)
          : rawReward is Map
              ? MissionRewardModel.fromJson(
                  Map<String, dynamic>.from(rawReward),
                )
              : const MissionRewardModel(xp: 0, cash: 0, gold: 0),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      progressRatio: (json['progress_ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}
