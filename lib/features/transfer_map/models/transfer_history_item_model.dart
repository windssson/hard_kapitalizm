class TransferHistoryProductModel {
  final String id;
  final String name;
  final String icon;

  const TransferHistoryProductModel({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory TransferHistoryProductModel.fromJson(Map<String, dynamic> json) {
    return TransferHistoryProductModel(
      id: (json['id'] ?? '').toString(),
      name: (json['urun_adi'] ?? 'Urun').toString(),
      icon: (json['urun_iconu'] ?? 'default.webp').toString(),
    );
  }
}

class TransferHistoryCityModel {
  final String id;
  final String name;

  const TransferHistoryCityModel({
    required this.id,
    required this.name,
  });

  factory TransferHistoryCityModel.fromJson(Map<String, dynamic> json) {
    return TransferHistoryCityModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Bilinmeyen Sehir').toString(),
    );
  }
}

class TransferHistoryEndpointModel {
  final String id;
  final String name;
  final String kind;
  final TransferHistoryCityModel city;

  const TransferHistoryEndpointModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.city,
  });

  factory TransferHistoryEndpointModel.fromJson(
    Map<String, dynamic> json, {
    String defaultKind = 'warehouse',
  }) {
    final resolvedKind = (json['kind'] ?? defaultKind).toString();
    final fallbackName = switch (resolvedKind) {
      'production' || 'production_inventory' => 'Uretim',
      'store' || 'store_slot' => 'Magaza',
      _ => 'Depo',
    };

    return TransferHistoryEndpointModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? fallbackName).toString(),
      kind: resolvedKind,
      city: TransferHistoryCityModel.fromJson(
        (json['city'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class TransferHistoryItemModel {
  final String id;
  final int quantity;
  final String status;
  final bool isRental;
  final double totalPrice;
  final double rentalCost;
  final DateTime startedAt;
  final DateTime finishAt;
  final DateTime? completedAt;
  final TransferHistoryProductModel product;
  final TransferHistoryEndpointModel sellerEndpoint;
  final TransferHistoryEndpointModel buyerEndpoint;
  final String sellerKind;
  final String buyerKind;

  const TransferHistoryItemModel({
    required this.id,
    required this.quantity,
    required this.status,
    required this.isRental,
    required this.totalPrice,
    required this.rentalCost,
    required this.startedAt,
    required this.finishAt,
    required this.completedAt,
    required this.product,
    required this.sellerEndpoint,
    required this.buyerEndpoint,
    required this.sellerKind,
    required this.buyerKind,
  });

  TransferHistoryEndpointModel get sellerWarehouse => sellerEndpoint;
  TransferHistoryEndpointModel get buyerWarehouse => buyerEndpoint;

  factory TransferHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final sellerKind = _resolveHistoryEndpointKind(
      explicitKind: json['seller_entity_kind']?.toString(),
      warehouse: json['seller_warehouse'] as Map<String, dynamic>?,
      store: json['seller_store'] as Map<String, dynamic>?,
      production: json['seller_production_inventory'] as Map<String, dynamic>?,
    );
    final buyerKind = _resolveHistoryEndpointKind(
      explicitKind: json['buyer_entity_kind']?.toString(),
      warehouse: json['buyer_warehouse'] as Map<String, dynamic>?,
      store: json['buyer_store'] as Map<String, dynamic>?,
      production: json['buyer_production_inventory'] as Map<String, dynamic>?,
    );
    return TransferHistoryItemModel(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'completed').toString(),
      isRental: json['is_rental'] as bool? ?? false,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse(json['completed_at'].toString()),
      product: TransferHistoryProductModel.fromJson(
        (json['product'] as Map<String, dynamic>?) ?? const {},
      ),
      sellerEndpoint: TransferHistoryEndpointModel.fromJson(
        (json['seller_warehouse'] as Map<String, dynamic>?) ??
            (json['seller_store'] as Map<String, dynamic>?) ??
            (json['seller_production_inventory'] as Map<String, dynamic>?) ??
            const {},
        defaultKind: sellerKind,
      ),
      buyerEndpoint: TransferHistoryEndpointModel.fromJson(
        (json['buyer_warehouse'] as Map<String, dynamic>?) ??
            (json['buyer_store'] as Map<String, dynamic>?) ??
            (json['buyer_production_inventory'] as Map<String, dynamic>?) ??
            const {},
        defaultKind: buyerKind,
      ),
      sellerKind: _historyKindLabel(sellerKind),
      buyerKind: _historyKindLabel(buyerKind),
    );
  }
}

String _resolveHistoryEndpointKind({
  required String? explicitKind,
  required Map<String, dynamic>? warehouse,
  required Map<String, dynamic>? store,
  required Map<String, dynamic>? production,
}) {
  if (explicitKind != null && explicitKind.isNotEmpty) {
    return explicitKind;
  }
  if (warehouse != null && warehouse.isNotEmpty) return 'warehouse';
  if (store != null && store.isNotEmpty) return 'store_slot';
  if (production != null && production.isNotEmpty) return 'production_inventory';
  return 'warehouse';
}

String _historyKindLabel(String kind) {
  switch (kind) {
    case 'store':
    case 'store_slot':
      return 'Magaza';
    case 'production':
    case 'production_inventory':
      return 'Uretim';
    default:
      return 'Depo';
  }
}
