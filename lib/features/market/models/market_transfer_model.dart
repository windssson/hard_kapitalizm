class MarketTransferModel {
  final String id;
  final String productId;
  final String? buyerWarehouseId;
  final String? buyerStoreSlotId;
  final String transferType;
  final int quantity;
  final String status;
  final DateTime startedAt;
  final DateTime finishAt;
  final bool isRental;
  final double totalPrice;
  final double rentalCost;
  final double transportCost;

  const MarketTransferModel({
    required this.id,
    required this.productId,
    required this.buyerWarehouseId,
    required this.buyerStoreSlotId,
    required this.transferType,
    required this.quantity,
    required this.status,
    required this.startedAt,
    required this.finishAt,
    required this.isRental,
    required this.totalPrice,
    required this.rentalCost,
    required this.transportCost,
  });

  factory MarketTransferModel.fromJson(Map<String, dynamic> json) {
    return MarketTransferModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      buyerWarehouseId: json['buyer_warehouse_id']?.toString(),
      buyerStoreSlotId: json['buyer_store_slot_id']?.toString(),
      transferType:
          (json['transfer_type'] ?? 'market_to_warehouse').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'in_transit').toString(),
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      isRental: json['is_rental'] as bool? ?? false,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
      transportCost: (json['transport_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}
