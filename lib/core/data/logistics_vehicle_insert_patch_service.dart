import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';

bool isLogisticsVehicleInsertPatch(EntityPatch patch) {
  return patch.entity == 'logistics_vehicle' &&
      patch.operation == PatchOperation.insert;
}

/// Prevents an insert patch from turning an unloaded multi-row vehicle provider
/// into a fake one-item list. If the authoritative list is already loaded, the
/// new vehicle is appended locally; otherwise the insert is consumed and the
/// provider's normal fetch remains authoritative when it is first watched.
class LogisticsVehicleInsertPatchService {
  LogisticsVehicleInsertPatchService(this._ref);

  final Ref _ref;

  bool apply(EntityPatch patch) {
    if (!isLogisticsVehicleInsertPatch(patch)) return false;

    final current = _ref.read(logisticsVehicleListProvider).value;
    if (current == null) return true;
    if (current.any((vehicle) => vehicle.id == patch.id)) return true;

    try {
      final vehicle = LogisticsVehicleModel.fromJson({
        ...patch.changes,
        'id': patch.id,
      });
      _ref.read(logisticsVehicleListProvider.notifier).insertVehicle(vehicle);
    } catch (_) {
      // A malformed/older insert contract must not create a partial local list.
      // Refresh only the loaded vehicle list as a correctness fallback.
      _ref.invalidate(logisticsVehicleListProvider);
    }
    return true;
  }
}

final logisticsVehicleInsertPatchServiceProvider =
    Provider<LogisticsVehicleInsertPatchService>(
  LogisticsVehicleInsertPatchService.new,
);
