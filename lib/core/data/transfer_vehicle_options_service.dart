import 'package:supabase_flutter/supabase_flutter.dart';

class RouteTransferVehicleOptionsRequest {
  final String sourceCityId;
  final String targetCityId;
  final double totalVolume;

  const RouteTransferVehicleOptionsRequest({
    required this.sourceCityId,
    required this.targetCityId,
    required this.totalVolume,
  });
}

class TransferVehicleOptionsService {
  final SupabaseClient _supabase;
  static const _transferDisabledReason =
      'Transfer sistemi gecici olarak devre disi.';

  TransferVehicleOptionsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRouteOptions(
    RouteTransferVehicleOptionsRequest request,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_route_transfer_vehicle_options',
        params: {
          'p_source_city_id': request.sourceCityId,
          'p_target_city_id': request.targetCityId,
          'p_total_volume': request.totalVolume,
        },
      );

      return (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('get_route_transfer_vehicle_options') ||
          message.contains('does not exist') ||
          message.contains('not found')) {
        return const [
          {'disabled_reason': _transferDisabledReason},
        ];
      }
      rethrow;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('get_route_transfer_vehicle_options') ||
          message.contains('does not exist') ||
          message.contains('not found')) {
        return const [
          {'disabled_reason': _transferDisabledReason},
        ];
      }
      rethrow;
    }
  }
}

class TransferVehicleOptionsResult<T> {
  final List<T> options;
  final String? unavailableReason;
  final bool hasSelectableOptions;

  const TransferVehicleOptionsResult({
    required this.options,
    required this.unavailableReason,
    this.hasSelectableOptions = true,
  });
}

TransferVehicleOptionsResult<T> mapTransferVehicleOptions<T>({
  required List<Map<String, dynamic>> rows,
  required T Function(Map<String, dynamic> json) mapper,
}) {
  String? unavailableReason;
  final options = <T>[];
  int maxCapacity = 0;
  bool hasAnySelectable = false;

  final validRows = <Map<String, dynamic>>[];

  for (final row in rows) {
    final rawVehicleId = row['vehicle_id']?.toString();
    if (rawVehicleId == null || rawVehicleId.isEmpty) {
      unavailableReason ??= row['disabled_reason']?.toString();
      continue;
    }
    final canSelect = row['can_select'] as bool? ?? false;
    if (canSelect) {
      hasAnySelectable = true;
    }
    final cap = (row['capacity'] as num?)?.toInt() ?? 0;
    if (cap > maxCapacity) {
      maxCapacity = cap;
    }
    validRows.add(row);
  }

  // Fiyata ve uygunluk durumuna göre sıralama:
  // 1) Seçilebilir araçlar (can_select == true) en üstte
  // 2) Toplam maliyete göre artan sırada (en uygun fiyatlı araç en başta)
  // 3) Fiyat eşitse sefer süresine göre artan sırada (en hızlı araç önce)
  validRows.sort((a, b) {
    final canSelectA = a['can_select'] as bool? ?? false;
    final canSelectB = b['can_select'] as bool? ?? false;
    if (canSelectA != canSelectB) {
      return canSelectA ? -1 : 1;
    }

    double getEffectivePrice(Map<String, dynamic> r) {
      final tp = (r['total_price'] as num?)?.toDouble() ?? 0.0;
      if (tp > 0) return tp;
      final rc = (r['rental_cost'] as num?)?.toDouble() ?? 0.0;
      final fc = (r['fuel_cost'] as num?)?.toDouble() ?? 0.0;
      return rc + fc;
    }

    final priceA = getEffectivePrice(a);
    final priceB = getEffectivePrice(b);
    if ((priceA - priceB).abs() > 0.01) {
      return priceA.compareTo(priceB);
    }

    final durA = (a['estimated_duration_seconds'] as num?)?.toInt() ??
        ((a['duration_minutes'] as num?)?.toInt() ?? 0) * 60;
    final durB = (b['estimated_duration_seconds'] as num?)?.toInt() ??
        ((b['duration_minutes'] as num?)?.toInt() ?? 0) * 60;
    return durA.compareTo(durB);
  });

  for (final row in validRows.take(8)) {
    options.add(mapper(row));
  }

  if (options.isNotEmpty && !hasAnySelectable && unavailableReason == null) {
    unavailableReason =
        'Bu yükü tek seferde taşıyacak araç bulunmuyor (Maksimum araç kapasitesi: $maxCapacity m³). Lütfen miktarı azaltarak parça parça transfer edin.';
  }

  return TransferVehicleOptionsResult<T>(
    options: options,
    unavailableReason: unavailableReason,
    hasSelectableOptions: hasAnySelectable,
  );
}
