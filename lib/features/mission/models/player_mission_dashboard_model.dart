import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';

class PlayerMissionDashboardModel {
  final bool success;
  final PlayerMissionModel? mainMission;
  final List<PlayerMissionModel> mainMissions;
  final List<PlayerMissionModel> dailyMissions;
  final List<PlayerMissionModel> achievements;
  final List<PlayerMissionModel> weeklyMissions;
  final List<PlayerMissionModel> sideMissions;
  final int claimableCount;
  final int mainClaimableCount;
  final int dailyClaimableCount;
  final int achievementClaimableCount;
  final int weeklyClaimableCount;
  final int completedCount;
  final int dailyCompletedCount;
  final int totalCount;

  const PlayerMissionDashboardModel({
    required this.success,
    required this.mainMission,
    required this.mainMissions,
    required this.dailyMissions,
    required this.achievements,
    required this.weeklyMissions,
    required this.sideMissions,
    required this.claimableCount,
    required this.mainClaimableCount,
    required this.dailyClaimableCount,
    required this.achievementClaimableCount,
    required this.weeklyClaimableCount,
    required this.completedCount,
    required this.dailyCompletedCount,
    required this.totalCount,
  });

  bool get hasAnyMission =>
      mainMission != null ||
      dailyMissions.isNotEmpty ||
      achievements.isNotEmpty ||
      mainMissions.isNotEmpty;

  List<PlayerMissionModel> get allMissions => [
    ?mainMission,
    ...dailyMissions,
    ...achievements,
  ];

  int get inProgressCount =>
      allMissions.where((mission) => mission.isInProgress).length;

  double get completionRatio {
    if (totalCount <= 0) return 0;
    return (completedCount / totalCount).clamp(0, 1).toDouble();
  }

  factory PlayerMissionDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawMain = json['main_mission'];
    final rawMainList = (json['main_missions'] as List?) ?? const [];
    final rawDaily = (json['daily_missions'] as List?) ?? const [];
    final rawAchievements = (json['achievements'] as List?) ??
        (json['side_missions'] as List?) ??
        const [];
    final rawWeekly = (json['weekly_missions'] as List?) ?? const [];
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
      mainMissions: rawMainList
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      dailyMissions: rawDaily
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      achievements: rawAchievements
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      weeklyMissions: rawWeekly
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      sideMissions: rawSide
          .whereType<Map>()
          .map((item) => PlayerMissionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      claimableCount: (json['claimable_count'] as num?)?.toInt() ?? 0,
      mainClaimableCount: (json['main_claimable_count'] as num?)?.toInt() ?? 0,
      dailyClaimableCount: (json['daily_claimable_count'] as num?)?.toInt() ?? 0,
      achievementClaimableCount:
          (json['achievement_claimable_count'] as num?)?.toInt() ??
              (json['weekly_claimable_count'] as num?)?.toInt() ??
              0,
      weeklyClaimableCount: (json['weekly_claimable_count'] as num?)?.toInt() ?? 0,
      completedCount: (summaryMap['completed_count'] as num?)?.toInt() ?? 0,
      dailyCompletedCount:
          (summaryMap['daily_completed_count'] as num?)?.toInt() ?? 0,
      totalCount: (summaryMap['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  PlayerMissionDashboardModel copyWith({
    bool? success,
    PlayerMissionModel? mainMission,
    List<PlayerMissionModel>? mainMissions,
    List<PlayerMissionModel>? dailyMissions,
    List<PlayerMissionModel>? achievements,
    List<PlayerMissionModel>? weeklyMissions,
    List<PlayerMissionModel>? sideMissions,
    int? claimableCount,
    int? mainClaimableCount,
    int? dailyClaimableCount,
    int? achievementClaimableCount,
    int? weeklyClaimableCount,
    int? completedCount,
    int? dailyCompletedCount,
    int? totalCount,
  }) {
    return PlayerMissionDashboardModel(
      success: success ?? this.success,
      mainMission: mainMission ?? this.mainMission,
      mainMissions: mainMissions ?? this.mainMissions,
      dailyMissions: dailyMissions ?? this.dailyMissions,
      achievements: achievements ?? this.achievements,
      weeklyMissions: weeklyMissions ?? this.weeklyMissions,
      sideMissions: sideMissions ?? this.sideMissions,
      claimableCount: claimableCount ?? this.claimableCount,
      mainClaimableCount: mainClaimableCount ?? this.mainClaimableCount,
      dailyClaimableCount: dailyClaimableCount ?? this.dailyClaimableCount,
      achievementClaimableCount:
          achievementClaimableCount ?? this.achievementClaimableCount,
      weeklyClaimableCount: weeklyClaimableCount ?? this.weeklyClaimableCount,
      completedCount: completedCount ?? this.completedCount,
      dailyCompletedCount: dailyCompletedCount ?? this.dailyCompletedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
