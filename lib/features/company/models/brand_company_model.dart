class BrandCompanyModel {
  final String id;
  final String playerId;
  final String brandName;
  final bool isActive;
  final DateTime? createdAt;

  const BrandCompanyModel({
    required this.id,
    required this.playerId,
    required this.brandName,
    required this.isActive,
    required this.createdAt,
  });

  factory BrandCompanyModel.fromJson(Map<String, dynamic> json) {
    return BrandCompanyModel(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      brandName: (json['brand_name'] ?? '').toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
