class BrandCompanyProductModel {
  final String productId;
  final String productName;
  final String productIcon;
  final int maxQualityLevel;
  final bool isBranded;
  final DateTime? brandedAt;
  final String? watermarkAssetId;

  const BrandCompanyProductModel({
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.maxQualityLevel,
    required this.isBranded,
    required this.brandedAt,
    required this.watermarkAssetId,
  });

  factory BrandCompanyProductModel.fromJson(Map<String, dynamic> json) {
    return BrandCompanyProductModel(
      productId: (json['product_id'] ?? json['id'] ?? '').toString(),
      productName: (json['product_name'] ?? json['urun_adi'] ?? 'Ürün')
          .toString(),
      productIcon: (json['product_icon'] ?? json['urun_iconu'] ?? 'default.webp')
          .toString(),
      maxQualityLevel: (json['max_quality_level'] as num?)?.toInt() ?? 1,
      isBranded: json['is_branded'] as bool? ?? false,
      brandedAt: json['branded_at'] != null
          ? DateTime.tryParse(json['branded_at'].toString())
          : null,
      watermarkAssetId: json['watermark_asset_id']?.toString(),
    );
  }

  BrandCompanyProductModel copyWith({
    String? productId,
    String? productName,
    String? productIcon,
    int? maxQualityLevel,
    bool? isBranded,
    DateTime? brandedAt,
    String? watermarkAssetId,
  }) {
    return BrandCompanyProductModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productIcon: productIcon ?? this.productIcon,
      maxQualityLevel: maxQualityLevel ?? this.maxQualityLevel,
      isBranded: isBranded ?? this.isBranded,
      brandedAt: brandedAt ?? this.brandedAt,
      watermarkAssetId: watermarkAssetId ?? this.watermarkAssetId,
    );
  }
}
