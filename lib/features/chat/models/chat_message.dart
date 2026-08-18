class ChatLinkedProduct {
  final String slotId;
  final String productId;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final int quantity;
  final double price;

  const ChatLinkedProduct({
    required this.slotId,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.quantity,
    required this.price,
  });

  factory ChatLinkedProduct.fromJson(Map<String, dynamic> json) {
    return ChatLinkedProduct(
      slotId: (json['linked_listing_slot_id'] ?? '').toString(),
      productId: (json['linked_product_id'] ?? '').toString(),
      productName: (json['linked_product_name'] ?? 'Urun').toString(),
      productIcon: (json['linked_product_icon'] ?? 'default.webp').toString(),
      qualityLevel: (json['linked_product_quality_level'] as num?)?.toInt() ?? 1,
      quantity: (json['linked_product_quantity'] as num?)?.toInt() ?? 0,
      price: (json['linked_product_price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String playerId;
  final String playerName;
  final String avatarId;
  final int playerLevel;
  final String content;
  final DateTime createdAt;
  final ChatLinkedProduct? linkedProduct;

  const ChatMessage({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.avatarId,
    required this.playerLevel,
    required this.content,
    required this.createdAt,
    required this.linkedProduct,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final linkedProductId = json['linked_product_id']?.toString();
    final linkedSlotId = json['linked_listing_slot_id']?.toString();

    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      playerName: (json['player_name'] ?? 'Oyuncu').toString(),
      avatarId: (json['avatar_id'] ?? 'ae1.webp').toString(),
      playerLevel: (json['player_level'] as num?)?.toInt() ?? 1,
      content: (json['content'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
      linkedProduct:
          (linkedProductId == null || linkedProductId.isEmpty) &&
              (linkedSlotId == null || linkedSlotId.isEmpty)
          ? null
          : ChatLinkedProduct.fromJson(json),
    );
  }
}
