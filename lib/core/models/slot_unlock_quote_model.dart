class SlotUnlockQuoteModel {
  const SlotUnlockQuoteModel({
    required this.success,
    required this.canUnlock,
    required this.blockReason,
    required this.buildingKind,
    required this.entityId,
    required this.buildingTypeId,
    required this.name,
    required this.currentSlotCount,
    required this.maxSlotCount,
    required this.nextSlotIndex,
    required this.cashCost,
    required this.playerCash,
    required this.hasRequiredCash,
    required this.taxBlocked,
  });

  final bool success;
  final bool canUnlock;
  final String? blockReason;
  final String buildingKind;
  final String entityId;
  final String? buildingTypeId;
  final String name;
  final int currentSlotCount;
  final int maxSlotCount;
  final int? nextSlotIndex;
  final double? cashCost;
  final double playerCash;
  final bool hasRequiredCash;
  final bool taxBlocked;

  bool get isAtMaximum => blockReason == 'maximum_slots';

  factory SlotUnlockQuoteModel.fromJson(Map<String, dynamic> json) {
    return SlotUnlockQuoteModel(
      success: json['success'] == true,
      canUnlock: json['can_unlock'] == true,
      blockReason: json['block_reason']?.toString(),
      buildingKind: (json['building_kind'] ?? '').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      buildingTypeId: json['building_type_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      currentSlotCount: (json['current_slot_count'] as num?)?.toInt() ?? 0,
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 0,
      nextSlotIndex: (json['next_slot_index'] as num?)?.toInt(),
      cashCost: (json['cash_cost'] as num?)?.toDouble(),
      playerCash: (json['player_cash'] as num?)?.toDouble() ?? 0,
      hasRequiredCash: json['has_required_cash'] as bool? ?? false,
      taxBlocked: json['tax_blocked'] as bool? ?? false,
    );
  }
}
