class TransferMapCityModel {
  final String id;
  final String name;
  final double x;
  final double y;

  const TransferMapCityModel({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
  });

  factory TransferMapCityModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return TransferMapCityModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Sehir').toString(),
      x: parseNum(json['map_position_x']),
      y: parseNum(json['map_position_y']),
    );
  }
}

class TransferMapEndpointModel {
  final String id;
  final String name;
  final String kind;
  final TransferMapCityModel city;

  const TransferMapEndpointModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.city,
  });

  factory TransferMapEndpointModel.fromJson(
    Map<String, dynamic> json, {
    String defaultKind = 'warehouse',
  }) {
    final resolvedKind = (json['kind'] ?? defaultKind).toString();
    return TransferMapEndpointModel(
      id: (json['id'] ?? '').toString(),
      name: _normalizeEndpointName(
        (json['name'] ?? 'Depo').toString(),
        resolvedKind,
      ),
      kind: resolvedKind,
      city: TransferMapCityModel.fromJson(
        (json['city'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  factory TransferMapEndpointModel.fromFlatJson(
    Map<String, dynamic> json, {
    required String endpointIdKey,
    required String endpointNameKey,
    required String cityIdKey,
    required String cityNameKey,
    required String cityXKey,
    required String cityYKey,
    String? kindKey,
    String defaultKind = 'warehouse',
  }) {
    final resolvedKind = (json[kindKey] ?? defaultKind).toString();
    return TransferMapEndpointModel(
      id: (json[endpointIdKey] ?? '').toString(),
      name: _normalizeEndpointName(
        (json[endpointNameKey] ?? 'Depo').toString(),
        resolvedKind,
      ),
      kind: resolvedKind,
      city: TransferMapCityModel(
        id: (json[cityIdKey] ?? '').toString(),
        name: (json[cityNameKey] ?? 'Sehir').toString(),
        x: _parseNum(json[cityXKey]),
        y: _parseNum(json[cityYKey]),
      ),
    );
  }
}

class TransferMapProductModel {
  final String id;
  final String name;
  final String icon;

  const TransferMapProductModel({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory TransferMapProductModel.fromJson(Map<String, dynamic> json) {
    return TransferMapProductModel(
      id: (json['id'] ?? '').toString(),
      name: (json['urun_adi'] ?? 'Urun').toString(),
      icon: (json['urun_iconu'] ?? 'default.webp').toString(),
    );
  }
}

class TransferMapItemModel {
  static const String defaultBrandId = '00000000-0000-0000-0000-000000000000';

  final String id;
  final int quantity;
  final int itemCount;
  final int totalQuantity;
  final int qualityLevel;
  final String brandId;
  final String? brandName;
  final String status;
  final String transferType;
  final bool isRental;
  final double totalPrice;
  final double rentalCost;
  final double transportCost;
  final DateTime startedAt;
  final DateTime finishAt;
  final TransferMapProductModel product;
  final TransferMapEndpointModel sellerEndpoint;
  final TransferMapEndpointModel buyerEndpoint;

  const TransferMapItemModel({
    required this.id,
    required this.quantity,
    required this.itemCount,
    required this.totalQuantity,
    required this.qualityLevel,
    required this.brandId,
    required this.brandName,
    required this.status,
    required this.transferType,
    required this.isRental,
    required this.totalPrice,
    required this.rentalCost,
    required this.transportCost,
    required this.startedAt,
    required this.finishAt,
    required this.product,
    required this.sellerEndpoint,
    required this.buyerEndpoint,
  });

  TransferMapEndpointModel get sellerWarehouse => sellerEndpoint;
  TransferMapEndpointModel get buyerWarehouse => buyerEndpoint;

  String get sellerKindLabel => _kindLabel(sellerEndpoint.kind);
  String get buyerKindLabel => _kindLabel(buyerEndpoint.kind);
  bool get isMultiItem => itemCount > 1;
  bool get hasBrand => brandId != defaultBrandId;
  int get displayQuantity => totalQuantity > 0 ? totalQuantity : quantity;
  String get displayTitle =>
      isMultiItem ? 'Coklu Sevkiyat ($itemCount kalem)' : product.name;

  factory TransferMapItemModel.fromJson(Map<String, dynamic> json) {
    final rentalCost = (json['rental_cost'] as num?)?.toDouble() ?? 0;
    return TransferMapItemModel(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 1,
      totalQuantity:
          (json['total_quantity'] as num?)?.toInt() ??
          (json['quantity'] as num?)?.toInt() ??
          0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      brandId: (json['brand_id'] ?? defaultBrandId).toString(),
      brandName: json['brand_name']?.toString(),
      status: (json['status'] ?? 'in_transit').toString(),
      transferType: (json['transfer_type'] ?? 'market_transfer').toString(),
      isRental: (json['is_rental'] as bool? ?? false) || rentalCost > 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: rentalCost,
      transportCost: (json['transport_cost'] as num?)?.toDouble() ?? 0,
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      product: TransferMapProductModel.fromJson(
        (json['product'] as Map<String, dynamic>?) ?? const {},
      ),
      sellerEndpoint: TransferMapEndpointModel.fromJson(
        (json['seller_warehouse'] as Map<String, dynamic>?) ??
            (json['seller_store'] as Map<String, dynamic>?) ??
            (json['seller_production_inventory'] as Map<String, dynamic>?) ??
            const {},
        defaultKind: _resolveEndpointKind(
          explicitKind: json['seller_entity_kind']?.toString(),
          warehouse: json['seller_warehouse'] as Map<String, dynamic>?,
          store: json['seller_store'] as Map<String, dynamic>?,
          production: json['seller_production_inventory'] as Map<String, dynamic>?,
        ),
      ),
      buyerEndpoint: TransferMapEndpointModel.fromJson(
        (json['buyer_warehouse'] as Map<String, dynamic>?) ??
            (json['buyer_store'] as Map<String, dynamic>?) ??
            (json['buyer_production_inventory'] as Map<String, dynamic>?) ??
            const {},
        defaultKind: _resolveEndpointKind(
          explicitKind: json['buyer_entity_kind']?.toString(),
          warehouse: json['buyer_warehouse'] as Map<String, dynamic>?,
          store: json['buyer_store'] as Map<String, dynamic>?,
          production: json['buyer_production_inventory'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  factory TransferMapItemModel.fromFlatJson(Map<String, dynamic> json) {
    final rentalCost = (json['rental_cost'] as num?)?.toDouble() ?? 0;
    return TransferMapItemModel(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 1,
      totalQuantity:
          (json['total_quantity'] as num?)?.toInt() ??
          (json['quantity'] as num?)?.toInt() ??
          0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      brandId: (json['brand_id'] ?? defaultBrandId).toString(),
      brandName: json['brand_name']?.toString(),
      status: (json['status'] ?? 'in_transit').toString(),
      transferType: (json['transfer_type'] ?? 'market_transfer').toString(),
      isRental: (json['is_rental'] as bool? ?? false) || rentalCost > 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: rentalCost,
      transportCost: (json['transport_cost'] as num?)?.toDouble() ?? 0,
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      product: TransferMapProductModel(
        id: (json['product_id'] ?? '').toString(),
        name: (json['product_name'] ?? 'Urun').toString(),
        icon: (json['product_icon'] ?? 'default.webp').toString(),
      ),
      sellerEndpoint: TransferMapEndpointModel.fromFlatJson(
        json,
        endpointIdKey: 'seller_warehouse_id',
        endpointNameKey: 'seller_warehouse_name',
        cityIdKey: 'seller_city_id',
        cityNameKey: 'seller_city_name',
        cityXKey: 'seller_city_x',
        cityYKey: 'seller_city_y',
        kindKey: 'seller_entity_kind',
        defaultKind: 'warehouse',
      ),
      buyerEndpoint: TransferMapEndpointModel.fromFlatJson(
        json,
        endpointIdKey: 'buyer_warehouse_id',
        endpointNameKey: 'buyer_warehouse_name',
        cityIdKey: 'buyer_city_id',
        cityNameKey: 'buyer_city_name',
        cityXKey: 'buyer_city_x',
        cityYKey: 'buyer_city_y',
        kindKey: 'buyer_entity_kind',
        defaultKind: 'warehouse',
      ),
    );
  }
}

String _resolveEndpointKind({
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

String _kindLabel(String kind) {
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

double _parseNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _normalizeEndpointName(String name, String kind) {
  if (kind != 'production' && kind != 'production_inventory') {
    return name;
  }

  final trimmed = name.trim();
  if (trimmed == 'Uretim Input' || trimmed == 'Uretim Output') {
    return 'Uretim';
  }

  if (trimmed.endsWith(' Input')) {
    return trimmed.substring(0, trimmed.length - 6).trimRight();
  }

  if (trimmed.endsWith(' Output')) {
    return trimmed.substring(0, trimmed.length - 7).trimRight();
  }

  return trimmed;
}

class TransferItemDetail {
  final String id;
  final String productId;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final String brandId;
  final String brandName;
  final int quantity;
  final double totalPrice;

  const TransferItemDetail({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.brandId,
    required this.brandName,
    required this.quantity,
    required this.totalPrice,
  });

  factory TransferItemDetail.fromJson(Map<String, dynamic> json) {
    return TransferItemDetail(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Urun',
      productIcon: json['product_icon']?.toString() ?? 'default.webp',
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      brandId: json['brand_id']?.toString() ?? '00000000-0000-0000-0000-000000000000',
      brandName: json['brand_name']?.toString() ?? 'Standart',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
    );
  }
}
