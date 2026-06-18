class WarehouseHistoryItemModel {
  static const String defaultBrandId = '00000000-0000-0000-0000-000000000000';

  final String id;
  final String direction;
  final String transferType;
  final String status;
  final DateTime happenedAt;
  final DateTime startedAt;
  final DateTime finishAt;
  final DateTime? completedAt;
  final String productId;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final String brandId;
  final String? brandName;
  final int quantity;
  final double totalPrice;
  final double transportCost;
  final double rentalCost;
  final bool isRental;
  final String sourceName;
  final String sourceKind;
  final String sourceCityName;
  final String targetName;
  final String targetKind;
  final String targetCityName;

  const WarehouseHistoryItemModel({
    required this.id,
    required this.direction,
    required this.transferType,
    required this.status,
    required this.happenedAt,
    required this.startedAt,
    required this.finishAt,
    required this.completedAt,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.brandId,
    required this.brandName,
    required this.quantity,
    required this.totalPrice,
    required this.transportCost,
    required this.rentalCost,
    required this.isRental,
    required this.sourceName,
    required this.sourceKind,
    required this.sourceCityName,
    required this.targetName,
    required this.targetKind,
    required this.targetCityName,
  });

  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';
  bool get hasBrand => brandId != defaultBrandId;
  bool get isSale =>
      isOutgoing &&
      (transferType.toLowerCase().contains('market') || totalPrice > 0);

  factory WarehouseHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final rentalCost = (json['rental_cost'] as num?)?.toDouble() ?? 0;
    return WarehouseHistoryItemModel(
      id: (json['id'] ?? '').toString(),
      direction: (json['direction'] ?? 'incoming').toString(),
      transferType: (json['transfer_type'] ?? '').toString(),
      status: (json['status'] ?? 'completed').toString(),
      happenedAt:
          DateTime.tryParse((json['happened_at'] ?? '').toString()) ??
          DateTime.now(),
      startedAt:
          DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      finishAt:
          DateTime.tryParse((json['finish_at'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse(json['completed_at'].toString()),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? 'Urun').toString(),
      productIcon: (json['product_icon'] ?? 'default.webp').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      brandId: (json['brand_id'] ?? defaultBrandId).toString(),
      brandName: json['brand_name']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      transportCost: (json['transport_cost'] as num?)?.toDouble() ?? 0,
      rentalCost: rentalCost,
      isRental: (json['is_rental'] as bool? ?? false) || rentalCost > 0,
      sourceName: (json['source_name'] ?? 'Kaynak').toString(),
      sourceKind: (json['source_kind'] ?? 'warehouse').toString(),
      sourceCityName: (json['source_city_name'] ?? '-').toString(),
      targetName: (json['target_name'] ?? 'Hedef').toString(),
      targetKind: (json['target_kind'] ?? 'warehouse').toString(),
      targetCityName: (json['target_city_name'] ?? '-').toString(),
    );
  }
}
