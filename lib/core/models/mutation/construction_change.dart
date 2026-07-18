/// İnşaat değişimleri (yeni inşaat, tamamlama, iptal vb.)
class ConstructionChange {
  final String? constructionId;
  final String? buildingKind;
  final String? status;
  final DateTime? finishAt;
  final String? entityId;
  final Map<String, dynamic> raw;

  const ConstructionChange({
    this.constructionId,
    this.buildingKind,
    this.status,
    this.finishAt,
    this.entityId,
    required this.raw,
  });

  factory ConstructionChange.fromJson(Map<String, dynamic> json) {
    return ConstructionChange(
      constructionId:
          json['construction_id']?.toString() ?? json['id']?.toString(),
      buildingKind: json['building_kind']?.toString(),
      status: json['status']?.toString(),
      finishAt: json['finish_at'] != null
          ? DateTime.tryParse(json['finish_at'].toString())
          : null,
      entityId: json['entity_id']?.toString(),
      raw: json,
    );
  }

  static ConstructionChange? tryExtract(
    Map<String, dynamic> response,
    String key,
  ) {
    final value = response[key];
    if (value is Map) {
      return ConstructionChange.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}
