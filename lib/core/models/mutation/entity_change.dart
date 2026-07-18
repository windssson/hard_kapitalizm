/// Entity-level değişimler (mağaza, fabrika, depo vb.)
class EntityChange {
  final String? entityId;
  final String? entityKind;
  final bool? isActive;
  final int? level;
  final double? cash;
  final Map<String, dynamic> raw;

  const EntityChange({
    this.entityId,
    this.entityKind,
    this.isActive,
    this.level,
    this.cash,
    required this.raw,
  });

  factory EntityChange.fromJson(Map<String, dynamic> json) {
    return EntityChange(
      entityId: json['entity_id']?.toString() ?? json['id']?.toString(),
      entityKind: json['entity_kind']?.toString() ?? json['kind']?.toString(),
      isActive: json['is_active'] as bool?,
      level: (json['level'] as num?)?.toInt(),
      cash: (json['cash'] as num?)?.toDouble(),
      raw: json,
    );
  }

  static EntityChange? tryExtract(Map<String, dynamic> response, String key) {
    final value = response[key];
    if (value is Map) {
      return EntityChange.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}
