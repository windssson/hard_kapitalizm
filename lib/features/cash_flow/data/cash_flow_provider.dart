import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/cash_flow/models/cash_movement_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cashMovementEntriesProvider =
    FutureProvider.autoDispose<List<CashMovementEntryModel>>((ref) async {
      final service = CashFlowService(Supabase.instance.client);
      return service.fetchEntries();
    });

class CashFlowService {
  CashFlowService(this._supabase);

  final SupabaseClient _supabase;

  static const Map<String, String> _categoryLabels = {
    'achievement_reward': 'Basarim Odulu',
    'mission_reward': 'Gorev Odulu',
    'store_sale': 'Magaza Satisi',
    'market_purchase': 'Pazar Alimi',
    'building_construction': 'Bina Insaati',
    'arge_research': 'AR-GE Arastirmasi',
  };

  static const Map<String, String> _referenceTypeLabels = {
    'store': 'Magaza',
    'city': 'Sehir',
    'product': 'Urun',
    'logistics_transfer': 'Lojistik Transfer',
    'warehouse': 'Depo',
    'factory': 'Fabrika',
    'farm': 'Ciftlik',
    'field': 'Tarla',
    'mine': 'Maden',
  };

  static const List<({String name, Map<String, dynamic> params})>
  _rpcCandidates = [
    (name: 'get_player_cash_ledger', params: {'p_limit': 200, 'p_offset': 0}),
  ];

  static const List<String> _tableCandidates = [
    'player_cash_movements',
    'cash_movements',
    'player_cash_history',
    'cash_history',
    'player_cash_transactions',
    'cash_transactions',
  ];

  Future<List<CashMovementEntryModel>> fetchEntries() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    for (final rpc in _rpcCandidates) {
      try {
        final params = <String, dynamic>{...rpc.params};
        if (params.containsKey('p_player_id')) {
          params['p_player_id'] = user.id;
        }
        final response = await _supabase.rpc(rpc.name, params: params);
        return _parseRows(response);
      } on PostgrestException catch (error) {
        if (_isMissingDatabaseObject(error)) {
          continue;
        }
        rethrow;
      }
    }

    for (final tableName in _tableCandidates) {
      try {
        dynamic response;
        try {
          response = await _supabase
              .from(tableName)
              .select()
              .eq('player_id', user.id);
        } on PostgrestException catch (error) {
          final message = error.message.toLowerCase();
          if (!message.contains('player_id')) {
            rethrow;
          }
          response = await _supabase.from(tableName).select();
        }
        return _parseRows(response);
      } on PostgrestException catch (error) {
        if (_isMissingDatabaseObject(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'Cash hareketleri icin uygun tablo veya fonksiyon bulunamadi. '
      'Beklenen adlardan biri: ${[..._rpcCandidates, ..._tableCandidates].join(', ')}',
    );
  }

  bool _isMissingDatabaseObject(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('does not exist') ||
        message.contains('not found') ||
        message.contains('could not find') ||
        message.contains('relation') ||
        message.contains('function');
  }

  List<CashMovementEntryModel> _parseRows(dynamic response) {
    dynamic rawRows = response;
    if (response is Map) {
      final json = Map<String, dynamic>.from(response);
      if (json['items'] is List) {
        rawRows = json['items'];
      } else if (json['data'] is List) {
        rawRows = json['data'];
      } else if (json['rows'] is List) {
        rawRows = json['rows'];
      } else {
        rawRows = [json];
      }
    }

    final rows = rawRows is List
        ? rawRows
        : rawRows == null
        ? const []
        : [rawRows];

    final entries =
        rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .map(_mapEntry)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return entries;
  }

  CashMovementEntryModel _mapEntry(Map<String, dynamic> json) {
    final amount = _resolveAmount(json);
    final createdAt =
        _readDateTime(json, const [
          'created_at',
          'happened_at',
          'movement_at',
          'transaction_at',
          'logged_at',
          'updated_at',
        ]) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final rawTitle =
        _readString(json, const [
          'title',
          'reason',
          'category_label',
          'action_label',
          'transaction_type',
          'movement_type',
          'entry_type',
          'type',
          'category',
        ]) ??
        (amount >= 0 ? 'Cash Girisi' : 'Cash Cikisi');
    final title = _localizeCategory(rawTitle);

    return CashMovementEntryModel(
      id:
          _readString(json, const ['id', 'movement_id', 'transaction_id']) ??
          '${createdAt.microsecondsSinceEpoch}_$amount',
      amount: amount,
      createdAt: createdAt,
      title: title,
      description: _readString(json, const [
        'description',
        'details',
        'note',
        'source_label',
        'reference_label',
      ]),
      balanceAfter: _readDouble(json, const [
        'balance_after',
        'cash_after',
        'new_cash',
        'current_cash',
        'balance',
      ]),
      category: _readString(json, const [
        'category',
        'transaction_type',
        'movement_type',
        'entry_type',
        'type',
      ])?.let(_localizeCategory),
      referenceId: _readString(json, const [
        'reference_id',
        'related_id',
        'entity_id',
        'owner_id',
      ]),
      referenceType: _readString(json, const [
        'reference_type',
        'entity_type',
        'owner_kind',
        'source_type',
        'ref_kind',
      ])?.let(_localizeReferenceType),
      raw: json,
    );
  }

  double _resolveAmount(Map<String, dynamic> json) {
    final amount = _readDouble(json, const [
      'amount',
      'cash_amount',
      'delta_amount',
      'change_amount',
      'net_amount',
      'value',
    ]);

    if (amount == null) return 0;

    final direction = _readString(json, const [
      'direction',
      'movement_direction',
      'flow',
      'entry_side',
    ])?.toLowerCase();
    final type = _readString(json, const [
      'type',
      'entry_type',
      'movement_type',
      'transaction_type',
      'category',
    ])?.toLowerCase();

    final isExpenseByText =
        (direction?.contains('out') ?? false) ||
        (direction?.contains('debit') ?? false) ||
        (direction?.contains('expense') ?? false) ||
        (type?.contains('expense') ?? false) ||
        (type?.contains('debit') ?? false) ||
        (type?.contains('out') ?? false);

    if (amount < 0) return amount;
    return isExpenseByText ? -amount : amount;
  }

  String _formatTitle(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _localizeCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return value;
    return _categoryLabels[normalized] ?? _formatTitle(value);
  }

  String _localizeReferenceType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return value;
    return _referenceTypeLabels[normalized] ?? _formatTitle(value);
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }
}

extension _NullableStringTransform on String? {
  String? let(String Function(String value) transform) {
    final value = this;
    if (value == null) return null;
    return transform(value);
  }
}
