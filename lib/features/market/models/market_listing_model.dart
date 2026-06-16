class MarketListingModel {
  final String listingId;
  final String slotId;
  final String productId;
  final String productName;
  final String productIcon;
  final String brandId;
  final double unitVolume;
  final String warehouseId;
  final String warehouseName;
  final String? warehouseIcon;
  final String cityId;
  final String cityName;
  final double cityX;
  final double cityY;
  final String sellerPlayerId;
  final String sellerPlayerName;
  final String sellerAvatarId;
  final int quantity;
  final int qualityLevel;
  final double price;
  final double cost;
  final bool isAvailableForSale;
  final bool isNpc;

  const MarketListingModel({
    required this.listingId,
    required this.slotId,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.brandId,
    required this.unitVolume,
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseIcon,
    required this.cityId,
    required this.cityName,
    required this.cityX,
    required this.cityY,
    required this.sellerPlayerId,
    required this.sellerPlayerName,
    required this.sellerAvatarId,
    required this.quantity,
    required this.qualityLevel,
    required this.price,
    required this.cost,
    required this.isAvailableForSale,
    this.isNpc = false,
  });

  factory MarketListingModel.npc({
    required String productId,
    required double price,
    required String cityId,
    required String cityName,
    required double cityX,
    required double cityY,
  }) {
    return MarketListingModel(
      listingId: 'npc:$productId',
      slotId: 'npc:$productId',
      productId: productId,
      productName: 'NPC Urunu',
      productIcon: 'default.webp',
      brandId: '00000000-0000-0000-0000-000000000000',
      unitVolume: 0,
      warehouseId: 'npc',
      warehouseName: 'Toptan Depo',
      warehouseIcon: 'market.webp',
      cityId: cityId,
      cityName: cityName,
      cityX: cityX,
      cityY: cityY,
      sellerPlayerId: 'npc',
      sellerPlayerName: 'Toptan Ticaret',
      sellerAvatarId: 'ae1.webp',
      quantity: 18500,
      qualityLevel: 1,
      price: price,
      cost: price,
      isAvailableForSale: true,
      isNpc: true,
    );
  }

  factory MarketListingModel.fromJson(Map<String, dynamic> json) {
    final warehouseJson = json['warehouse'] as Map<String, dynamic>? ?? {};
    final cityJson = warehouseJson['city'] as Map<String, dynamic>? ?? {};
    final warehouseTypeJson =
        warehouseJson['warehouse_type'] as Map<String, dynamic>? ?? {};
    final productJson = json['product'] as Map<String, dynamic>? ?? {};

    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return MarketListingModel(
      listingId: (json['listing_id'] ?? json['id'] ?? json['slot_id'] ?? '')
          .toString(),
      slotId: (json['slot_id'] ?? json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? productJson['id'] ?? '').toString(),
      productName:
          (json['product_name'] ?? productJson['urun_adi'] ?? 'Urun')
              .toString(),
      productIcon:
          (json['product_icon'] ?? productJson['urun_iconu'] ?? 'default.webp')
              .toString(),
      brandId:
          (json['brand_id'] ?? '00000000-0000-0000-0000-000000000000')
              .toString(),
      unitVolume: parseNum(
        json['unit_volume'] ?? productJson['birim_hacim'],
      ),
      warehouseId: (json['warehouse_id'] ?? '').toString(),
      warehouseName:
          (json['warehouse_name'] ?? warehouseJson['name'] ?? 'Depo')
              .toString(),
      warehouseIcon:
          json['warehouse_icon']?.toString() ??
          warehouseTypeJson['icon']?.toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (json['city_name'] ?? cityJson['name'] ?? 'Bilinmeyen')
          .toString(),
      cityX: parseNum(json['city_x'] ?? cityJson['map_position_x']),
      cityY: parseNum(json['city_y'] ?? cityJson['map_position_y']),
      sellerPlayerId: (json['seller_player_id'] ?? '').toString(),
      sellerPlayerName:
          (json['seller_player_name'] ?? json['player_name'] ?? 'Oyuncu')
              .toString(),
      sellerAvatarId:
          (json['seller_avatar_id'] ?? json['avatar_id'] ?? 'ae1.webp')
              .toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      isAvailableForSale: json['is_available_for_sale'] as bool? ?? false,
      isNpc: json['is_npc'] as bool? ?? false,
    );
  }
}
