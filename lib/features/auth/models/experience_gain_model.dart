class ExperienceGainModel {
  final bool success;
  final int amount;
  final String? reason;
  final int oldLevel;
  final int newLevel;
  final int oldExperience;
  final int newExperience;
  final bool leveledUp;
  final int levelsGained;

  const ExperienceGainModel({
    required this.success,
    required this.amount,
    required this.reason,
    required this.oldLevel,
    required this.newLevel,
    required this.oldExperience,
    required this.newExperience,
    required this.leveledUp,
    required this.levelsGained,
  });

  factory ExperienceGainModel.fromJson(Map<String, dynamic> json) {
    return ExperienceGainModel(
      success: json['success'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString(),
      oldLevel: (json['old_level'] as num?)?.toInt() ?? 1,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 1,
      oldExperience: (json['old_experience'] as num?)?.toInt() ?? 0,
      newExperience: (json['new_experience'] as num?)?.toInt() ?? 0,
      leveledUp: json['leveled_up'] as bool? ?? false,
      levelsGained: (json['levels_gained'] as num?)?.toInt() ?? 0,
    );
  }
}
