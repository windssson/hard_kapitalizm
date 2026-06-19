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

  const TransferVehicleOptionsResult({
    required this.options,
    required this.unavailableReason,
  });

  bool get hasSelectableOptions => options.isNotEmpty;
}

TransferVehicleOptionsResult<T> mapTransferVehicleOptions<T>({
  required List<Map<String, dynamic>> rows,
  required T Function(Map<String, dynamic> json) mapper,
}) {
  String? unavailableReason;
  final options = <T>[];

  for (final row in rows) {
    final rawVehicleId = row['vehicle_id']?.toString();
    if (rawVehicleId == null || rawVehicleId.isEmpty) {
      unavailableReason ??= row['disabled_reason']?.toString();
      continue;
    }
    options.add(mapper(row));
  }

  return TransferVehicleOptionsResult<T>(
    options: options,
    unavailableReason: unavailableReason,
  );
}
