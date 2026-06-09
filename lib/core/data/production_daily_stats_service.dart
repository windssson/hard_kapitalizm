import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/production_daily_stat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductionDailyStatsQuery {
  final String? ownerKind;
  final String? ownerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const ProductionDailyStatsQuery({
    this.ownerKind,
    this.ownerId,
    this.dateFrom,
    this.dateTo,
  });

  @override
  bool operator ==(Object other) {
    return other is ProductionDailyStatsQuery &&
        other.ownerKind == ownerKind &&
        other.ownerId == ownerId &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode => Object.hash(ownerKind, ownerId, dateFrom, dateTo);
}

class ProductionDailyStatsService {
  final SupabaseClient _supabase;

  ProductionDailyStatsService(this._supabase);

  Future<List<ProductionDailyStatModel>> getPlayerDailyProductionStats({
    String? ownerKind,
    String? ownerId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase.rpc(
      'get_player_daily_production_stats',
      params: {
        'p_owner_kind': ownerKind,
        'p_owner_id': ownerId,
        'p_date_from': dateFrom?.toUtc().toIso8601String().split('T').first,
        'p_date_to': dateTo?.toUtc().toIso8601String().split('T').first,
      },
    );

    final rows = response as List<dynamic>? ?? const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => ProductionDailyStatModel.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }
}

final productionDailyStatsServiceProvider =
    Provider<ProductionDailyStatsService>((ref) {
      return ProductionDailyStatsService(Supabase.instance.client);
    });

final productionDailyStatsProvider =
    FutureProvider.family<List<ProductionDailyStatModel>, ProductionDailyStatsQuery>((
      ref,
      query,
    ) async {
      final service = ref.watch(productionDailyStatsServiceProvider);
      return service.getPlayerDailyProductionStats(
        ownerKind: query.ownerKind,
        ownerId: query.ownerId,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      );
    });
