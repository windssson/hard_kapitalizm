class PlayerModel {
  final String id;
  final String playerName;
  final String companyName;
  final String avatarId;
  final int level;
  final int experience;
  final double cash;
  final double gold;
  final DateTime createdAt;

  PlayerModel({
    required this.id,
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.level,
    required this.experience,
    required this.cash,
    required this.gold,
    required this.createdAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      playerName: json['player_name'] as String? ?? 'Oyuncu',
      companyName: json['company_name'] as String? ?? 'Yeni Holding',
      avatarId: json['avatar_id'] as String? ?? 'ae1.webp',
      level: json['level'] as int? ?? 1,
      experience: json['experience'] as int? ?? 0,
      cash: (json['cash'] as num?)?.toDouble() ?? 100000.0,
      gold: (json['gold'] as num?)?.toDouble() ?? 100.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_name': playerName,
      'company_name': companyName,
      'avatar_id': avatarId,
      'level': level,
      'experience': experience,
      'cash': cash,
      'gold': gold,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
