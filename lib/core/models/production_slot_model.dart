import 'package:hard_kapitalizm/core/models/product_model.dart';

class ProductionSlotContractModel {
  const ProductionSlotContractModel({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.slotIndex,
    required this.productId,
    required this.brandId,
    required this.qualityLevel,
    required this.boostMultiplier,
    required this.isActive,
    required this.product,
    this.lastProductionAt,
  });

  static const zeroBrandId = '00000000-0000-0000-0000-000000000000';

  final String id;
  final String ownerKind;
  final String ownerId;
  final int slotIndex;
  final String? productId;
  final String brandId;
  final int qualityLevel;
  final double boostMultiplier;
  final bool isActive;
  final ProductModel? product;
  final DateTime? lastProductionAt;

  bool get isEmpty => productId == null || productId!.isEmpty;
  bool get isConfigured => !isEmpty && qualityLevel > 0;

  factory ProductionSlotContractModel.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    return ProductionSlotContractModel(
      id: (json['id'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id']?.toString(),
      brandId: (json['brand_id'] ?? zeroBrandId).toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      product: rawProduct is Map
          ? ProductModel.fromJson(Map<String, dynamic>.from(rawProduct))
          : null,
      lastProductionAt: _parseDateTime(json['last_production_at']),
    );
  }

  ProductionSlotContractModel copyWith({
    String? id,
    String? ownerKind,
    String? ownerId,
    int? slotIndex,
    String? productId,
    String? brandId,
    int? qualityLevel,
    double? boostMultiplier,
    bool? isActive,
    ProductModel? product,
    DateTime? lastProductionAt,
  }) {
    return ProductionSlotContractModel(
      id: id ?? this.id,
      ownerKind: ownerKind ?? this.ownerKind,
      ownerId: ownerId ?? this.ownerId,
      slotIndex: slotIndex ?? this.slotIndex,
      productId: productId ?? this.productId,
      brandId: brandId ?? this.brandId,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      boostMultiplier: boostMultiplier ?? this.boostMultiplier,
      isActive: isActive ?? this.isActive,
      product: product ?? this.product,
      lastProductionAt: lastProductionAt ?? this.lastProductionAt,
    );
  }

  /// Merge a backend patch while preserving explicit null semantics.
  /// In particular `product_id: null` must clear a configured slot instead of
  /// falling back to the previous product as a conventional copyWith would.
  ProductionSlotContractModel applyPatch(
    Map<String, dynamic> changes, {
    ProductModel? resolvedProduct,
  }) {
    final hasProduct = changes.containsKey('product_id');
    final nextProductId = hasProduct
        ? changes['product_id']?.toString()
        : productId;
    final productChanged = hasProduct && nextProductId != productId;
    final nextProduct = productChanged
        ? resolvedProduct
        : (resolvedProduct ?? product);

    final hasLastProduction = changes.containsKey('last_production_at');
    final nextLastProduction = hasLastProduction
        ? _parseDateTime(changes['last_production_at'])
        : lastProductionAt;

    return ProductionSlotContractModel(
      id: (changes['id'] ?? id).toString(),
      ownerKind: (changes['owner_kind'] ?? ownerKind).toString(),
      ownerId: (changes['owner_id'] ?? ownerId).toString(),
      slotIndex: (changes['slot_index'] as num?)?.toInt() ?? slotIndex,
      productId: nextProductId,
      brandId: (changes['brand_id'] ??
              (nextProductId == null || nextProductId.isEmpty
                  ? zeroBrandId
                  : brandId))
          .toString(),
      qualityLevel: (changes['quality_level'] as num?)?.toInt() ??
          (nextProductId == null || nextProductId.isEmpty ? 0 : qualityLevel),
      boostMultiplier:
          (changes['boost_multiplier'] as num?)?.toDouble() ?? boostMultiplier,
      isActive: changes['is_active'] as bool? ?? isActive,
      product: nextProduct,
      lastProductionAt: nextLastProduction,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
