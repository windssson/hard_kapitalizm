import 'package:hard_kapitalizm/core/models/mutation/player_changes.dart';

/// RPC response'larından ortak alanları parse eden yardımcı sınıf.
/// Null-safe; eksik alanlar silenctly ignore edilir.
class MutationResponse {
  final bool success;
  final String? message;
  final PlayerChanges? playerChanges;
  final bool historyDirty;
  final bool performanceDirty;
  final bool dashboardDirty;
  final bool notificationDirty;
  final bool missionDirty;
  final bool achievementDirty;
  final bool taxDirty;
  final Map<String, dynamic> raw;

  const MutationResponse({
    required this.success,
    this.message,
    this.playerChanges,
    this.historyDirty = false,
    this.performanceDirty = false,
    this.dashboardDirty = false,
    this.notificationDirty = false,
    this.missionDirty = false,
    this.achievementDirty = false,
    this.taxDirty = false,
    required this.raw,
  });

  factory MutationResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;

    // player değişikliklerini bul
    final playerChanges = PlayerChanges.tryExtract(json);

    // changed bloğundan dirty flagleri çıkar
    final changed = json['changed'];
    final changedMap =
        changed is Map ? Map<String, dynamic>.from(changed) : const <String, dynamic>{};

    bool getBool(String key) =>
        changedMap[key] == true || json[key] == true;

    return MutationResponse(
      success: success,
      message: json['message']?.toString(),
      playerChanges: playerChanges,
      historyDirty: getBool('history_dirty'),
      performanceDirty: getBool('performance_dirty'),
      dashboardDirty: getBool('dashboard_dirty'),
      notificationDirty: getBool('notification_dirty'),
      missionDirty: getBool('mission_dirty'),
      achievementDirty: getBool('achievement_dirty'),
      taxDirty: getBool('tax_dirty'),
      raw: json,
    );
  }

  /// Success olmayan yanıtlar için hızlı factory
  factory MutationResponse.failure(String message) {
    return MutationResponse(
      success: false,
      message: message,
      raw: {'success': false, 'message': message},
    );
  }
}
