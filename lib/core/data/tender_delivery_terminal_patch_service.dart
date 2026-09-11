import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';

bool isTenderDeliveryFailureTerminalStatus(String status) {
  return const {'failed', 'failed_late', 'expired'}.contains(status.toLowerCase());
}

/// `EntityPatchDispatcher` already decrements the tender-center active delivery
/// counter for delete/completed/cancelled patches. Runtime processing can also
/// terminate a delivery as failed/failed_late (and older data can expose
/// expired). Those statuses are removed from active detail state by the
/// lifecycle guard, so the aggregate counter must advance in the same patch.
class TenderDeliveryTerminalPatchService {
  TenderDeliveryTerminalPatchService(this._ref);

  final Ref _ref;

  void apply(EntityPatch patch) {
    if (patch.entity != 'tender_delivery' ||
        patch.operation != PatchOperation.update) {
      return;
    }

    final status = patch.changes['status']?.toString() ?? '';
    if (!isTenderDeliveryFailureTerminalStatus(status)) return;

    _ref.read(tenderCenterProvider.notifier).patchDeliveryCount(-1);
  }
}

final tenderDeliveryTerminalPatchServiceProvider =
    Provider<TenderDeliveryTerminalPatchService>(
  TenderDeliveryTerminalPatchService.new,
);
