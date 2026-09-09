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

  static const Object _financeUnset = Object();

  LogisticsFinanceEntryModel copyWith({
    String? id,
    String? playerId,
    Object? logisticsCompanyId = _financeUnset,
    Object? vehicleId = _financeUnset,
    String? entryType,
    String? category,
    double? amount,
    Object? quantity = _financeUnset,
    Object? unitCost = _financeUnset,
    Object? relatedTransferId = _financeUnset,
    Object? relatedWarehouseSlotId = _financeUnset,
    Object? relatedMarketListingId = _financeUnset,
    Object? description = _financeUnset,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return LogisticsFinanceEntryModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      logisticsCompanyId: identical(logisticsCompanyId, _financeUnset)
          ? this.logisticsCompanyId
          : logisticsCompanyId as String?,
      vehicleId: identical(vehicleId, _financeUnset)
          ? this.vehicleId
          : vehicleId as String?,
      entryType: entryType ?? this.entryType,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      quantity: identical(quantity, _financeUnset)
          ? this.quantity
          : quantity as double?,
      unitCost: identical(unitCost, _financeUnset)
          ? this.unitCost
          : unitCost as double?,
      relatedTransferId: identical(relatedTransferId, _financeUnset)
          ? this.relatedTransferId
          : relatedTransferId as String?,
      relatedWarehouseSlotId: identical(relatedWarehouseSlotId, _financeUnset)
          ? this.relatedWarehouseSlotId
          : relatedWarehouseSlotId as String?,
      relatedMarketListingId: identical(relatedMarketListingId, _financeUnset)
          ? this.relatedMarketListingId
          : relatedMarketListingId as String?,
      description: identical(description, _financeUnset)
          ? this.description
          : description as String?,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

