import 'package:flutter/foundation.dart';

enum PatchOperation {
  insert,
  update,
  delete,
}

/// Supabase RPC `changed.patches[]` içindeki entity bazlı mutasyon kaydı.
class EntityPatch {
  final String entity;
  final String id;
  final PatchOperation operation;
  final Map<String, dynamic> changes;

  const EntityPatch({
    required this.entity,
    required this.id,
    required this.operation,
    required this.changes,
  });

  factory EntityPatch.fromJson(Map<String, dynamic> json) {
    final entity = json['entity']?.toString().trim() ?? '';
    final id = json['id']?.toString().trim() ?? '';
    final opStr = json['operation']?.toString().trim().toLowerCase() ?? '';

    if (entity.isEmpty) {
      throw const FormatException('EntityPatch.entity is required.');
    }
    if (id.isEmpty) {
      throw const FormatException('EntityPatch.id is required.');
    }

    final operation = switch (opStr) {
      'insert' => PatchOperation.insert,
      'delete' => PatchOperation.delete,
      'update' => PatchOperation.update,
      _ => throw FormatException(
          'Unrecognized patch operation: "$opStr" for entity "$entity".',
        ),
    };

    final rawChanges = json['changes'];
    if (rawChanges != null && rawChanges is! Map) {
      throw FormatException(
        'EntityPatch.changes must be a map for $entity/$id.',
      );
    }
    final changes = rawChanges is Map
        ? Map<String, dynamic>.from(rawChanges)
        : const <String, dynamic>{};

    return EntityPatch(
      entity: entity,
      id: id,
      operation: operation,
      changes: changes,
    );
  }

  /// Güvenli parse yardımcısı. Bozuk/gelecekte tanınmayan bir patch'in tüm
  /// mutation response'unu bozmasına izin vermez.
  static EntityPatch? tryFromJson(Map<String, dynamic> json) {
    try {
      return EntityPatch.fromJson(json);
    } catch (e) {
      debugPrint('[EntityPatch] malformed patch skipped: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'entity': entity,
      'id': id,
      'operation': operation.name,
      'changes': changes,
    };
  }

  @override
  String toString() =>
      'EntityPatch(entity: $entity, id: $id, operation: ${operation.name}, changes: $changes)';
}
