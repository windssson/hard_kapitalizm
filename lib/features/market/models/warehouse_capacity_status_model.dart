class WarehouseCapacityStatusModel {
  final String warehouseId;
  final double totalCapacity;
  final double usedCapacity;
  final double reservedCapacity;
  final double availableCapacity;

  const WarehouseCapacityStatusModel({
    required this.warehouseId,
    required this.totalCapacity,
    required this.usedCapacity,
    required this.reservedCapacity,
    required this.availableCapacity,
  });

  factory WarehouseCapacityStatusModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return WarehouseCapacityStatusModel(
      warehouseId: (json['warehouse_id'] ?? '').toString(),
      totalCapacity: parseNum(json['total_capacity']),
      usedCapacity: parseNum(json['used_capacity']),
      reservedCapacity: parseNum(json['reserved_capacity']),
      availableCapacity: parseNum(json['available_capacity']),
    );
  }
}
