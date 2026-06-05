class LogisticsFinanceEntryModel {
  final String id;
  final String playerId;
  final String? logisticsCompanyId;
  final String? vehicleId;
  final String entryType;
  final String category;
  final double amount;
  final double? quantity;
  final double? unitCost;
  final String? relatedTransferId;
  final String? relatedWarehouseSlotId;
  final String? relatedMarketListingId;
  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const LogisticsFinanceEntryModel({
    required this.id,
    required this.playerId,
    required this.logisticsCompanyId,
    required this.vehicleId,
    required this.entryType,
    required this.category,
    required this.amount,
    required this.quantity,
    required this.unitCost,
    required this.relatedTransferId,
    required this.relatedWarehouseSlotId,
    required this.relatedMarketListingId,
    required this.description,
    required this.metadata,
    required this.createdAt,
  });

  factory LogisticsFinanceEntryModel.fromJson(Map<String, dynamic> json) {
    return LogisticsFinanceEntryModel(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      logisticsCompanyId: json['logistics_company_id']?.toString(),
      vehicleId: json['vehicle_id']?.toString(),
      entryType: (json['entry_type'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitCost: (json['unit_cost'] as num?)?.toDouble(),
      relatedTransferId: json['related_transfer_id']?.toString(),
      relatedWarehouseSlotId: json['related_warehouse_slot_id']?.toString(),
      relatedMarketListingId: json['related_market_listing_id']?.toString(),
      description: json['description']?.toString(),
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?) ?? const {},
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isIncome => entryType == 'income';
  bool get isExpense => entryType == 'expense';
}
