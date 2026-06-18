import 'package:hard_kapitalizm/core/models/product_model.dart';

class SelectableProductionProductModel {
  static const String defaultBrandId = '00000000-0000-0000-0000-000000000000';

  final ProductModel product;
  final int maxQualityLevel;
  final String preferredBrandId;

  const SelectableProductionProductModel({
    required this.product,
    required this.maxQualityLevel,
    required this.preferredBrandId,
  });

  factory SelectableProductionProductModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final maxQualityLevel = (json['max_quality_level'] as num?)?.toInt() ?? 1;

    return SelectableProductionProductModel(
      product: ProductModel.fromJson(json),
      maxQualityLevel: maxQualityLevel.clamp(1, 5),
      preferredBrandId:
          (json['preferred_brand_id'] ?? defaultBrandId)
              .toString(),
    );
  }

  bool get hasPreferredBrand => preferredBrandId != defaultBrandId;
}
