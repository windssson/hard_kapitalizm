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

class TransferMapWarehouseModel {
  final String id;
  final String name;
  final TransferMapCityModel city;

  const TransferMapWarehouseModel({
    required this.id,
    required this.name,
    required this.city,
  });

  factory TransferMapWarehouseModel.fromJson(Map<String, dynamic> json) {
    return TransferMapWarehouseModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Depo').toString(),
      city: TransferMapCityModel.fromJson(
        (json['city'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  factory TransferMapWarehouseModel.fromFlatJson(
    Map<String, dynamic> json, {
    required String warehouseIdKey,
    required String warehouseNameKey,
    required String cityIdKey,
    required String cityNameKey,
    required String cityXKey,
    required String cityYKey,
  }) {
    return TransferMapWarehouseModel(
      id: (json[warehouseIdKey] ?? '').toString(),
      name: (json[warehouseNameKey] ?? 'Depo').toString(),
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
  final String id;
  final int quantity;
  final String status;
  final bool isRental;
  final double totalPrice;
  final double rentalCost;
  final DateTime startedAt;
  final DateTime finishAt;
  final TransferMapProductModel product;
  final TransferMapWarehouseModel sellerWarehouse;
  final TransferMapWarehouseModel buyerWarehouse;

  const TransferMapItemModel({
    required this.id,
    required this.quantity,
    required this.status,
    required this.isRental,
    required this.totalPrice,
    required this.rentalCost,
    required this.startedAt,
    required this.finishAt,
    required this.product,
    required this.sellerWarehouse,
    required this.buyerWarehouse,
  });

  factory TransferMapItemModel.fromJson(Map<String, dynamic> json) {
    return TransferMapItemModel(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'in_transit').toString(),
      isRental: json['is_rental'] as bool? ?? false,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      product: TransferMapProductModel.fromJson(
        (json['product'] as Map<String, dynamic>?) ?? const {},
      ),
      sellerWarehouse: TransferMapWarehouseModel.fromJson(
        (json['seller_warehouse'] as Map<String, dynamic>?) ?? const {},
      ),
      buyerWarehouse: TransferMapWarehouseModel.fromJson(
        (json['buyer_warehouse'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  factory TransferMapItemModel.fromFlatJson(Map<String, dynamic> json) {
    return TransferMapItemModel(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'in_transit').toString(),
      isRental: json['is_rental'] as bool? ?? false,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      product: TransferMapProductModel(
        id: (json['product_id'] ?? '').toString(),
        name: (json['product_name'] ?? 'Urun').toString(),
        icon: (json['product_icon'] ?? 'default.webp').toString(),
      ),
      sellerWarehouse: TransferMapWarehouseModel.fromFlatJson(
        json,
        warehouseIdKey: 'seller_warehouse_id',
        warehouseNameKey: 'seller_warehouse_name',
        cityIdKey: 'seller_city_id',
        cityNameKey: 'seller_city_name',
        cityXKey: 'seller_city_x',
        cityYKey: 'seller_city_y',
      ),
      buyerWarehouse: TransferMapWarehouseModel.fromFlatJson(
        json,
        warehouseIdKey: 'buyer_warehouse_id',
        warehouseNameKey: 'buyer_warehouse_name',
        cityIdKey: 'buyer_city_id',
        cityNameKey: 'buyer_city_name',
        cityXKey: 'buyer_city_x',
        cityYKey: 'buyer_city_y',
      ),
    );
  }
}

double _parseNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
