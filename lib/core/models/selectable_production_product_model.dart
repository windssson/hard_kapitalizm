import 'package:hard_kapitalizm/core/models/product_model.dart';

class SelectableProductionProductModel {
  final ProductModel product;
  final int maxQualityLevel;

  const SelectableProductionProductModel({
    required this.product,
    required this.maxQualityLevel,
  });

  factory SelectableProductionProductModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final maxQualityLevel = (json['max_quality_level'] as num?)?.toInt() ?? 1;

    return SelectableProductionProductModel(
      product: ProductModel.fromJson(json),
      maxQualityLevel: maxQualityLevel.clamp(1, 5),
    );
  }
}
