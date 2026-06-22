import 'package:hard_kapitalizm/features/company/models/brand_design_options.dart';

class BrandCompanyModel {
  final String id;
  final String playerId;
  final String brandName;
  final bool isActive;
  final DateTime? createdAt;
  final int brandLevel;
  final int brandXp;
  final String logoId;
  final String themeColor;

  const BrandCompanyModel({
    required this.id,
    required this.playerId,
    required this.brandName,
    required this.isActive,
    required this.createdAt,
    required this.brandLevel,
    required this.brandXp,
    required this.logoId,
    required this.themeColor,
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
      brandLevel: json['brand_level'] as int? ?? 1,
      brandXp: (json['brand_xp'] ?? 0) is int
          ? json['brand_xp'] as int
          : int.tryParse(json['brand_xp'].toString()) ?? 0,
      logoId: json['logo_id'] as String? ?? defaultBrandLogoId,
      themeColor: json['theme_color'] as String? ?? '#E5C05C',
    );
  }
}
