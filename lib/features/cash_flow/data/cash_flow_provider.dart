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
    // Categories
    'achievement_reward': 'Başarım Ödülü',
    'mission_reward': 'Görev Ödülü',
    'daily_streak_reward': 'Günlük Giriş Ödülü',
    'store_sale': 'Mağaza Satışı',
    'store_sales': 'Mağaza Satışları',
    'store_purchase': 'Mağaza Alımı',
    'sales': 'Satış Geliri',
    'market_purchase': 'Pazar Alımı',
    'market_sale': 'Pazar Satışı',
    'building_construction': 'Bina İnşaatı',
    'building_sale': 'Tesis Satış İadesi',
    'factory_sale': 'Fabrika Satışı',
    'farm_sale': 'Tarla Satışı',
    'field_sale': 'Çiftlik Satışı',
    'mine_sale': 'Maden Satışı',
    'warehouse_sale': 'Depo Satışı',
    'factory_construction': 'Fabrika İnşaatı',
    'farm_construction': 'Tarla İnşaatı',
    'field_construction': 'Çiftlik İnşaatı',
    'mine_construction': 'Maden İnşaatı',
    'store_construction': 'Mağaza İnşaatı',
    'warehouse_construction': 'Depo İnşaatı',
    'arge_research': 'Ar-Ge Araştırması',
    'arge_construction': 'Ar-Ge Merkezi Kurulumu',
    'loan_payout': 'Kredi Çekimi',
    'loan_payment': 'Kredi Taksit Ödemesi',
    'loan_payment_auto': 'Otomatik Taksit Tahsilatı',
    'deposit_placed': 'Vadeli Mevduat Açılışı',
    'deposit_claimed': 'Mevduat Tahsilatı',
    'deposit_early_withdrawal': 'Mevduat Erken Kapatma',
    'building_upgrade': 'Bina Yükseltme',
    'warehouse_expansion': 'Depo Genişletme',
    'warehouse_upgrade': 'Depo Yükseltme',
    'tax_payment': 'Vergi Ödemesi',
    'tax_debt_payment': 'Vergi Borcu Ödemesi',
    'sales_tax': 'Satış Vergisi',
    'vehicle_purchase': 'Araç Satın Alımı',
    'vehicle_repair': 'Araç Bakım/Onarım',
    'vehicle_rental_income': 'Araç Kiralama Geliri',
    'license_purchase': 'Lisans Satın Alımı',
    'reward': 'Ödül',
    'tender_bid': 'İhale Teklifi',
    'tender_award': 'İhale Kazanımı',
    'transfer_cost': 'Nakliye / Sevk Maliyeti',
    'tender_reward_paid': 'İhale Hakediş Ödemesi',
    'tender_bond_paid': 'İhale Teminat Ödemesi',
    'tender_bond_refunded': 'İhale Teminat İadesi',
    'tender_bid_bond_paid': 'İhale Teklif Teminatı',
    'tender_bid_bond_refunded': 'İhale Teklif Teminat İadesi',
    'tender_delivery_transport_paid': 'İhale Sevkiyat Maliyeti',
    'logistics_construction': 'Lojistik Tesisi Kurulumu',
    'marketing_campaign': 'Pazarlama Kampanyası',
    'brand_registration': 'Marka Tescil Harcı',
  };

  static const Map<String, String> _referenceTypeLabels = {
    // Reference Kinds / Reference Types
    'store': 'Mağaza',
    'city': 'Şehir',
    'product': 'Ürün',
    'logistics_transfer': 'Lojistik Transfer',
    'warehouse': 'Depo',
    'factory': 'Fabrika',
    'farm': 'Tarla',
    'field': 'Çiftlik',
    'mine': 'Maden',
    'loan': 'Banka Kredisi',
    'deposit': 'Vadeli Mevduat',
    'tax': 'Vergi Dairesi',
    'logistics': 'Lojistik',
    'mission': 'Görev Sistemi',
    'tender': 'Kamu İhalesi',
    'building': 'Bina Kurumu',
    'player': 'Oyuncu İşlemi',
    'arge_center': 'Ar-Ge Merkezi',
    'player_tender': 'Kamu İhalesi',
    'tender_bid': 'İhale Teklifi',
    'logistics_company': 'Lojistik Şirketi',
    'vehicle': 'Araç',
    'brand': 'Marka Şirketi',
  };

  static const List<({String name, Map<String, dynamic> params})>
  _rpcCandidates = [
    (name: 'get_player_cash_ledger', params: {'p_limit': 200, 'p_offset': 0}),
  ];

  static const List<String> _tableCandidates = [
    'player_cash_ledger',
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
