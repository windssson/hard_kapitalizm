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
    final opStr = json['operation']?.toString().toLowerCase() ?? 'update';
    final operation = switch (opStr) {
      'insert' => PatchOperation.insert,
      'delete' => PatchOperation.delete,
      _ => PatchOperation.update,
    };

    final rawChanges = json['changes'];
    final changes = rawChanges is Map
        ? Map<String, dynamic>.from(rawChanges)
        : const <String, dynamic>{};

    return EntityPatch(
      entity: json['entity']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      operation: operation,
      changes: changes,
    );
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
