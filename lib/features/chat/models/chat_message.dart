class ChatMessage {
  final String id;
  final String playerId;
  final String playerName;
  final String avatarId;
  final int playerLevel;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.avatarId,
    required this.playerLevel,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      playerName: json['player_name'] as String,
      avatarId: json['avatar_id'] as String? ?? 'ae1.webp',
      playerLevel: json['player_level'] as int? ?? 1,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
