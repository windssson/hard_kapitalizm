class PlayerActiveProductModel {
  final String productId;
  final int quantity;
  final String sourceKind; // 'store', 'factory', 'farm', 'mine', 'field'
  final String sourceName; // Name of the store or production unit
  final String sourceId;   // Unique ID of the store or production unit
  final String role;       // 'sale' (store slot), 'output' (produced), 'input' (raw material)
  final String? productName;
  final String? productIcon;

  PlayerActiveProductModel({
    required this.productId,
    required this.quantity,
    required this.sourceKind,
    required this.sourceName,
    required this.sourceId,
    required this.role,
    this.productName,
    this.productIcon,
  });

  factory PlayerActiveProductModel.fromJson(Map<String, dynamic> json) {
    return PlayerActiveProductModel(
      productId: (json['product_id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      sourceKind: (json['source_kind'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      sourceId: (json['source_id'] ?? '').toString(),
      role: (json['role'] ?? 'sale').toString(),
      productName: json['product_name'] as String?,
      productIcon: json['product_icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'source_kind': sourceKind,
      'source_name': sourceName,
      'source_id': sourceId,
      'role': role,
      'product_name': productName,
      'product_icon': productIcon,
    };
  }

  @override
  String toString() {
    return 'PlayerActiveProductModel(productId: $productId, quantity: $quantity, sourceKind: $sourceKind, sourceName: $sourceName, sourceId: $sourceId, role: $role, productName: $productName)';
  }
}
