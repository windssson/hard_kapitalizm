class RequiredMaterialModel {
  const RequiredMaterialModel({
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.missingQuantity,
    required this.hasEnough,
  });

  final String productId;
  final String productName;
  final String productIcon;
  final double requiredQuantity;
  final double availableQuantity;
  final double missingQuantity;
  final bool hasEnough;

  factory RequiredMaterialModel.fromJson(Map<String, dynamic> json) {
    final required = (json['required_quantity'] as num?)?.toDouble() ?? 0;
    final available = (json['available_quantity'] as num?)?.toDouble() ?? 0;
    final missing =
        (json['missing_quantity'] as num?)?.toDouble() ??
        (required - available).clamp(0, double.infinity).toDouble();

    return RequiredMaterialModel(
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? json['product_id'] ?? '').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      requiredQuantity: required,
      availableQuantity: available,
      missingQuantity: missing,
      hasEnough: json['has_enough'] as bool? ?? missing <= 0,
    );
  }
}
