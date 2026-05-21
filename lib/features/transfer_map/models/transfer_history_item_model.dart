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
      name: (json['name'] ?? 'Sehir').toString(),
    );
  }
}

class TransferHistoryWarehouseModel {
  final String id;
  final String name;
  final TransferHistoryCityModel city;

  const TransferHistoryWarehouseModel({
    required this.id,
    required this.name,
    required this.city,
  });

  factory TransferHistoryWarehouseModel.fromJson(Map<String, dynamic> json) {
    return TransferHistoryWarehouseModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Depo').toString(),
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
  final TransferHistoryWarehouseModel sellerWarehouse;
  final TransferHistoryWarehouseModel buyerWarehouse;
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
    required this.sellerWarehouse,
    required this.buyerWarehouse,
    required this.sellerKind,
    required this.buyerKind,
  });

  factory TransferHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final hasSellerWarehouse =
        (json['seller_warehouse'] as Map<String, dynamic>?) != null;
    final hasBuyerWarehouse =
        (json['buyer_warehouse'] as Map<String, dynamic>?) != null;
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
      sellerWarehouse: TransferHistoryWarehouseModel.fromJson(
        (json['seller_warehouse'] as Map<String, dynamic>?) ??
            (json['seller_store'] as Map<String, dynamic>?) ??
            const {},
      ),
      buyerWarehouse: TransferHistoryWarehouseModel.fromJson(
        (json['buyer_warehouse'] as Map<String, dynamic>?) ??
            (json['buyer_store'] as Map<String, dynamic>?) ??
            const {},
      ),
      sellerKind: hasSellerWarehouse ? 'Depo' : 'Magaza',
      buyerKind: hasBuyerWarehouse ? 'Depo' : 'Magaza',
    );
  }
}
