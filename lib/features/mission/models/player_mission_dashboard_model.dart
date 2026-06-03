import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';

class PlayerMissionDashboardModel {
  final bool success;
  final PlayerMissionModel? mainMission;
  final List<PlayerMissionModel> dailyMissions;
  final List<PlayerMissionModel> sideMissions;
  final int claimableCount;
  final int dailyClaimableCount;
  final int completedCount;
  final int dailyCompletedCount;
  final int totalCount;

  const PlayerMissionDashboardModel({
    required this.success,
    required this.mainMission,
    required this.dailyMissions,
    required this.sideMissions,
    required this.claimableCount,
    required this.dailyClaimableCount,
    required this.completedCount,
    required this.dailyCompletedCount,
    required this.totalCount,
  });

  bool get hasAnyMission =>
      mainMission != null || dailyMissions.isNotEmpty || sideMissions.isNotEmpty;
  List<PlayerMissionModel> get allMissions => [
    if (mainMission != null) mainMission!,
    ...dailyMissions,
    ...sideMissions,
  ];
  int get inProgressCount =>
      allMissions.where((mission) => mission.isInProgress).length;
  double get completionRatio {
    if (totalCount <= 0) return 0;
    return (completedCount / totalCount).clamp(0, 1).toDouble();
  }

  factory PlayerMissionDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawMain = json['main_mission'];
    final rawDaily = (json['daily_missions'] as List?) ?? const [];
    final rawSide = (json['side_missions'] as List?) ?? const [];
    final rawSummary = json['summary'];

    final summaryMap = rawSummary is Map<String, dynamic>
        ? rawSummary
        : rawSummary is Map
            ? Map<String, dynamic>.from(rawSummary)
            : const <String, dynamic>{};

    return PlayerMissionDashboardModel(
      success: json['success'] as bool? ?? false,
      mainMission: rawMain is Map<String, dynamic>
          ? PlayerMissionModel.fromJson(rawMain)
          : rawMain is Map
              ? PlayerMissionModel.fromJson(Map<String, dynamic>.from(rawMain))
              : null,
      dailyMissions: rawDaily
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      sideMissions: rawSide
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      claimableCount: (json['claimable_count'] as num?)?.toInt() ?? 0,
      dailyClaimableCount: (json['daily_claimable_count'] as num?)?.toInt() ?? 0,
      completedCount: (summaryMap['completed_count'] as num?)?.toInt() ?? 0,
      dailyCompletedCount:
          (summaryMap['daily_completed_count'] as num?)?.toInt() ?? 0,
      totalCount: (summaryMap['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}
