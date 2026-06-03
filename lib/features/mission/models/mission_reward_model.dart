class MissionRewardModel {
  final int xp;
  final double cash;
  final int gold;

  const MissionRewardModel({
    required this.xp,
    required this.cash,
    required this.gold,
  });

  bool get hasAnyReward => xp > 0 || cash > 0 || gold > 0;

  factory MissionRewardModel.fromJson(Map<String, dynamic> json) {
    return MissionRewardModel(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      cash: (json['cash'] as num?)?.toDouble() ?? 0,
      gold: (json['gold'] as num?)?.toInt() ?? 0,
    );
  }
}
