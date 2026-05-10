class MarketTransferModel {
  final String id;
  final String productId;
  final int quantity;
  final String status;
  final DateTime startedAt;
  final DateTime finishAt;
  final bool isRental;
  final double totalPrice;
  final double rentalCost;

  const MarketTransferModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.status,
    required this.startedAt,
    required this.finishAt,
    required this.isRental,
    required this.totalPrice,
    required this.rentalCost,
  });

  factory MarketTransferModel.fromJson(Map<String, dynamic> json) {
    return MarketTransferModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'in_transit').toString(),
      startedAt: DateTime.parse(json['started_at'].toString()),
      finishAt: DateTime.parse(json['finish_at'].toString()),
      isRental: json['is_rental'] as bool? ?? false,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      rentalCost: (json['rental_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}
