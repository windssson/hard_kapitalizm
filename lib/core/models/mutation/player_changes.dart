import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

/// RPC response'larından gelen player değişim bilgilerini taşır.
/// Tüm alanlar opsiyoneldir; null gelirse mevcut state korunur.
class PlayerChanges {
  final PlayerModel? fullPlayer;
  final double? cash;
  final double? gold;
  final int? level;
  final int? experience;
  final String? avatarId;
  final String? companyName;

  const PlayerChanges({
    this.fullPlayer,
    this.cash,
    this.gold,
    this.level,
    this.experience,
    this.avatarId,
    this.companyName,
  });

  /// RPC response'undaki `changed.player` veya doğrudan `player` bloğundan parse eder.
  factory PlayerChanges.fromJson(Map<String, dynamic> json) {
    PlayerModel? full;
    try {
      if (json['id'] != null) {
        full = PlayerModel.fromJson(json);
      }
    } catch (_) {}

    return PlayerChanges(
      fullPlayer: full,
      cash: (json['cash'] as num?)?.toDouble(),
      gold: (json['gold'] as num?)?.toDouble(),
      level: (json['level'] as num?)?.toInt(),
      experience: (json['experience'] as num?)?.toInt(),
      avatarId: json['avatar_id']?.toString(),
      companyName: json['company_name']?.toString(),
    );
  }

  /// RPC response'unun üst bloğundan `changed.player` veya `player` alanını çıkarır.
  static PlayerChanges? tryExtract(Map<String, dynamic> response) {
    final changed = response['changed'];
    if (changed is Map) {
      final playerJson = changed['player'];
      if (playerJson is Map) {
        return PlayerChanges.fromJson(Map<String, dynamic>.from(playerJson));
      }
    }
    final playerJson = response['player'];
    if (playerJson is Map) {
      return PlayerChanges.fromJson(Map<String, dynamic>.from(playerJson));
    }
    return null;
  }
}
