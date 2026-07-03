import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/arge/data/arge_provider.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimedTaskRuntime extends ConsumerStatefulWidget {
  const TimedTaskRuntime({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TimedTaskRuntime> createState() => _TimedTaskRuntimeState();
}

class _TimedTaskRuntimeState extends ConsumerState<TimedTaskRuntime>
    with WidgetsBindingObserver {
  static const Duration _errorRetryInterval = Duration(seconds: 10);

  Timer? _timer;
  bool _isRunning = false;
  bool _needsReschedule = false;
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleNextRun(Duration.zero);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _scheduleNextRun(Duration.zero);
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          ref.read(pushNotificationServiceProvider).initialize();
        }
      } catch (_) {}
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool get _isForeground {
    final state = _lastLifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _onProviderUpdated() {
    if (_isRunning) {
      _needsReschedule = true;
      return;
    }
    _scheduleNextRun(Duration.zero);
  }

  void _scheduleNextRun(Duration? delay) {
    _timer?.cancel();
    _timer = null;
    if (delay == null) return;
    if (!mounted || !_isForeground) return;
    _timer = Timer(delay, _runCycle);
  }

  Duration? _capDelay(DateTime? nextDueAt) {
    if (nextDueAt == null) {
      return null;
    }

    final rawDelay = nextDueAt.difference(DateTime.now());
    if (rawDelay <= Duration.zero) {
      return Duration.zero;
    }

    return rawDelay;
  }

  Future<void> _runCycle() async {
    if (!mounted || !_isForeground || _isRunning) return;

    _isRunning = true;
    _needsReschedule = false;
    try {
      final snapshot = await _loadSnapshot();
      final now = DateTime.now();

      bool hasErrors = false;

      if (snapshot.nextDueAt != null && !snapshot.nextDueAt!.isAfter(now)) {
        final result = await _completeDueTasks(snapshot);
        hasErrors = result.hasErrors;
      }

      if (hasErrors) {
        _scheduleNextRun(_errorRetryInterval);
      } else {
        final nextDueAt = _calculateNextDueAt(snapshot, now);
        _scheduleNextRun(_capDelay(nextDueAt));
      }
    } catch (e, stackTrace) {
      debugPrint('Unhandled error in TimedTaskRuntime cycle: $e\n$stackTrace');
      _scheduleNextRun(_errorRetryInterval);
    } finally {
      _isRunning = false;
      if (_needsReschedule) {
        _needsReschedule = false;
        _scheduleNextRun(Duration.zero);
      }
    }
  }

  Future<T> _safeFuture<T>(Future<T> future, T defaultValue) async {
    try {
      return await future;
    } catch (e, stackTrace) {
      debugPrint('Error loading future in TimedTaskRuntime: $e\n$stackTrace');
      return defaultValue;
    }
  }

  Future<T?> _safeNullableFuture<T>(Future<T?> future) async {
    try {
      return await future;
    } catch (e, stackTrace) {
      debugPrint('Error loading nullable future in TimedTaskRuntime: $e\n$stackTrace');
      return null;
    }
  }

  Future<_TimedTaskSnapshot> _loadSnapshot() async {
    final transfersFuture = ref.read(buyerTransferMapProvider.future);
    final researchesFuture = ref.read(activeArgeResearchesProvider.future);
    final factoryConstructionFuture = ref.read(factoryConstructionProvider.future);
    final farmConstructionFuture = ref.read(farmConstructionProvider.future);
    final fieldConstructionFuture = ref.read(fieldConstructionProvider.future);
    final mineConstructionFuture = ref.read(mineConstructionProvider.future);
    final argeConstructionFuture = ref.read(playerArgeConstructionProvider.future);
    final logisticsConstructionFuture = ref.read(
      playerLogisticsConstructionProvider.future,
    );
    final storesFuture = ref.read(storesListProvider.future);
    final warehousesFuture = ref.read(warehouseListProvider.future);
    final activeUpgradeFuture = ref.read(anyActiveWarehouseUpgradeProvider.future);

    final transfers = await _safeFuture(transfersFuture, <TransferMapItemModel>[]);
    final researches = await _safeFuture(researchesFuture, <ArgeResearchModel>[]);
    final factoryConstruction = await _safeNullableFuture(factoryConstructionFuture);
    final farmConstruction = await _safeNullableFuture(farmConstructionFuture);
    final fieldConstruction = await _safeNullableFuture(fieldConstructionFuture);
    final mineConstruction = await _safeNullableFuture(mineConstructionFuture);
    final argeConstruction = await _safeNullableFuture(argeConstructionFuture);
    final logisticsConstruction = await _safeNullableFuture(logisticsConstructionFuture);
    final stores = await _safeFuture(storesFuture, <StoreModel>[]);
    final warehouses = await _safeFuture(warehousesFuture, <WarehouseModel>[]);
    final activeUpgrade = await _safeNullableFuture(activeUpgradeFuture);

    final constructions = <_TimedConstructionTask?>[
      _constructionFromMap(kind: 'factory', raw: factoryConstruction),
      _constructionFromMap(kind: 'farm', raw: farmConstruction),
      _constructionFromMap(kind: 'field', raw: fieldConstruction),
      _constructionFromMap(kind: 'mine', raw: mineConstruction),
      _constructionFromMap(kind: 'arge_center', raw: argeConstruction),
      _constructionFromMap(kind: 'logistics_company', raw: logisticsConstruction),
      ...stores
          .where((store) => store.isUnderConstruction && store.finishAt != null)
          .map(
            (store) => _TimedConstructionTask(
              kind: 'store',
              constructionId: store.id,
              finishAt: store.finishAt!,
              entityId: store.id,
            ),
          ),
      ...warehouses
          .where(
            (warehouse) =>
                warehouse.isUnderConstruction && warehouse.finishAt != null,
          )
          .map(
            (warehouse) => _TimedConstructionTask(
              kind: 'warehouse',
              constructionId: warehouse.id,
              finishAt: warehouse.finishAt!,
              entityId: warehouse.id,
            ),
          ),
    ].whereType<_TimedConstructionTask>().toList();

    DateTime? nextDueAt;

    for (final transfer in transfers) {
      if (transfer.status != 'in_transit' || !_canAutoCompleteTransfer(transfer)) {
        continue;
      }
      nextDueAt = _earlier(nextDueAt, transfer.finishAt);
    }

    for (final research in researches) {
      nextDueAt = _earlier(nextDueAt, research.finishAt);
    }

    for (final construction in constructions) {
      nextDueAt = _earlier(nextDueAt, construction.finishAt);
    }

    if (activeUpgrade?.isInProgress == true) {
      nextDueAt = _earlier(nextDueAt, activeUpgrade!.finishAt);
    }

    return _TimedTaskSnapshot(
      transfers: transfers,
      constructions: constructions,
      activeUpgrade: activeUpgrade,
      nextDueAt: nextDueAt,
      researches: researches,
    );
  }

  DateTime? _calculateNextDueAt(_TimedTaskSnapshot snapshot, DateTime relativeTo) {
    DateTime? nextDueAt;

    for (final transfer in snapshot.transfers) {
      if (transfer.status != 'in_transit' || !_canAutoCompleteTransfer(transfer)) {
        continue;
      }
      if (transfer.finishAt.isAfter(relativeTo)) {
        nextDueAt = _earlier(nextDueAt, transfer.finishAt);
      }
    }

    for (final research in snapshot.researches) {
      if (research.finishAt.isAfter(relativeTo)) {
        nextDueAt = _earlier(nextDueAt, research.finishAt);
      }
    }

    for (final construction in snapshot.constructions) {
      if (construction.finishAt.isAfter(relativeTo)) {
        nextDueAt = _earlier(nextDueAt, construction.finishAt);
      }
    }

    final activeUpgrade = snapshot.activeUpgrade;
    if (activeUpgrade?.isInProgress == true && activeUpgrade!.finishAt.isAfter(relativeTo)) {
      nextDueAt = _earlier(nextDueAt, activeUpgrade.finishAt);
    }

    return nextDueAt;
  }

  _TimedConstructionTask? _constructionFromMap({
    required String kind,
    required Map<String, dynamic>? raw,
  }) {
    if (raw == null) return null;

    final constructionId = raw['id']?.toString() ?? '';
    final finishAt = DateTime.tryParse(raw['finish_at']?.toString() ?? '');
    if (constructionId.isEmpty || finishAt == null) {
      return null;
    }

    return _TimedConstructionTask(
      kind: kind,
      constructionId: constructionId,
      finishAt: finishAt,
      entityId: raw['entity_id']?.toString(),
    );
  }

  Future<_CompletionResult> _completeDueTasks(_TimedTaskSnapshot snapshot) async {
    final now = DateTime.now();
    var didChange = false;
    var hasErrors = false;

    final dueTransfers = snapshot.transfers
        .where(
          (transfer) =>
              transfer.status == 'in_transit' &&
              _canAutoCompleteTransfer(transfer) &&
              !transfer.finishAt.isAfter(now),
        )
        .toList();
    if (dueTransfers.isNotEmpty) {
      didChange = true;
      final err = await _completeDueTransfers(dueTransfers);
      if (err) hasErrors = true;
    }

    final dueResearches = snapshot.researches
        .where((research) => !research.finishAt.isAfter(now))
        .toList();
    if (dueResearches.isNotEmpty) {
      didChange = true;
      final err = await _completeDueResearches(dueResearches);
      if (err) hasErrors = true;
    }

    final dueConstructions = snapshot.constructions
        .where((construction) => !construction.finishAt.isAfter(now))
        .toList();
    if (dueConstructions.isNotEmpty) {
      didChange = true;
      final err = await _completeDueConstructions(dueConstructions);
      if (err) hasErrors = true;
    }

    final activeUpgrade = snapshot.activeUpgrade;
    if (activeUpgrade != null &&
        activeUpgrade.isInProgress &&
        !activeUpgrade.finishAt.isAfter(now)) {
      didChange = true;
      final err = await _completeDueBuildingUpgrades(activeUpgrade);
      if (err) hasErrors = true;
    }

    return _CompletionResult(
      processedSomething: didChange,
      hasErrors: hasErrors,
    );
  }

  Future<bool> _completeDueTransfers(List<TransferMapItemModel> transfers) async {
    final action = ref.read(warehouseActionProvider);
    bool hasError = false;

    for (final transfer in transfers) {
      try {
        final result = await action.completeLogisticsTransfer(transfer.id);
        if (result['success'] == true) {
          _invalidateTransferTargets(result);
        } else {
          hasError = true;
          debugPrint('Transfer completion failed for ${transfer.id}: ${result['message'] ?? 'Unknown error'}');
        }
      } catch (e, stackTrace) {
        hasError = true;
        debugPrint('Failed to complete transfer ${transfer.id}: $e\n$stackTrace');
      }
    }

    ref.invalidate(buyerTransferMapProvider);
    ref.invalidate(buyerTransferHistoryProvider);
    ref.invalidate(playerProvider);

    return hasError;
  }

  Future<bool> _completeDueResearches(List<ArgeResearchModel> researches) async {
    final action = ref.read(argeActionProvider);
    bool hasError = false;
    for (final research in researches) {
      try {
        final researchId = research.id.toString();
        if (researchId.isEmpty) continue;
        final result = await action.completeResearch(researchId);
        if (result['success'] != true) {
          hasError = true;
          debugPrint('Research completion failed for $researchId: ${result['message'] ?? 'Unknown error'}');
        }
      } catch (e, stackTrace) {
        hasError = true;
        debugPrint('Failed to complete research ${research.id}: $e\n$stackTrace');
      }
    }
    return hasError;
  }

  Future<bool> _completeDueConstructions(
    List<_TimedConstructionTask> constructions,
  ) async {
    bool hasError = false;
    for (final construction in constructions) {
      try {
        Map<String, dynamic> result;
        switch (construction.kind) {
          case 'factory':
            result = await ref
                .read(factoryActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind('factory', entityId: construction.entityId);
            break;
          case 'farm':
            result = await ref
                .read(farmActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind('farm', entityId: construction.entityId);
            break;
          case 'field':
            result = await ref
                .read(fieldActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind('field', entityId: construction.entityId);
            break;
          case 'mine':
            result = await ref
                .read(mineActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind('mine', entityId: construction.entityId);
            break;
          case 'arge_center':
            result = await ref
                .read(argeActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind(
              'arge_center',
              entityId: construction.entityId,
            );
            break;
          case 'logistics_company':
            result = await ref
                .read(logisticsActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind(
              'logistics_company',
              entityId: construction.entityId,
            );
            break;
          case 'store':
            result = await ref
                .read(storeActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind('store', entityId: construction.entityId);
            break;
          case 'warehouse':
            result = await ref
                .read(warehouseActionProvider)
                .completeConstruction(construction.constructionId);
            _invalidateConstructionKind(
              'warehouse',
              entityId: construction.entityId,
            );
            break;
          default:
            result = {'success': false, 'message': 'Unknown construction kind: ${construction.kind}'};
        }
        if (result['success'] != true) {
          hasError = true;
          debugPrint('Construction completion failed for ${construction.constructionId} (${construction.kind}): ${result['message'] ?? 'Unknown error'}');
        }
      } catch (e, stackTrace) {
        hasError = true;
        debugPrint('Failed to complete construction ${construction.constructionId} (${construction.kind}): $e\n$stackTrace');
      }
    }
    return hasError;
  }

  Future<bool> _completeDueBuildingUpgrades(
    BuildingUpgradeModel activeUpgrade,
  ) async {
    bool hasError = false;
    try {
      await tryCompleteDueBuildingUpgrades(Supabase.instance.client);

      _invalidateUpgradeKind(
        activeUpgrade.buildingKind,
        entityId: activeUpgrade.entityId,
      );

      await ref.read(warehouseActionProvider).completeDueWarehouseUpgrades();
    } catch (e, stackTrace) {
      hasError = true;
      debugPrint('Failed to complete building upgrades: $e\n$stackTrace');
    } finally {
      ref.invalidate(playerProvider);
    }
    return hasError;
  }

  void _invalidateTransferTargets(Map<String, dynamic> result) {
    final warehouseIds = _affectedIds(result, 'warehouse_ids');
    final storeIds = _affectedIds(result, 'store_ids');
    final factoryIds = _affectedIds(result, 'factory_ids');
    final farmIds = _affectedIds(result, 'farm_ids');
    final fieldIds = _affectedIds(result, 'field_ids');
    final mineIds = _affectedIds(result, 'mine_ids');

    if (storeIds.isNotEmpty) {
      ref.invalidate(storesListProvider);
      for (final storeId in storeIds) {
        ref.invalidate(storeDetailPageProvider(storeId));
      }
    }

    if (warehouseIds.isNotEmpty) {
      ref.invalidate(warehouseListProvider);
      for (final warehouseId in warehouseIds) {
        ref.invalidate(warehouseDetailProvider(warehouseId));
      }
    }

    if (factoryIds.isNotEmpty) {
      ref.invalidate(factoryListProvider);
      for (final factoryId in factoryIds) {
        ref.invalidate(factoryDetailProvider(factoryId));
      }
    }

    if (farmIds.isNotEmpty) {
      ref.invalidate(farmListProvider);
      for (final farmId in farmIds) {
        ref.invalidate(farmDetailProvider(farmId));
      }
    }

    if (fieldIds.isNotEmpty) {
      ref.invalidate(fieldListProvider);
      for (final fieldId in fieldIds) {
        ref.invalidate(fieldDetailProvider(fieldId));
      }
    }

    if (mineIds.isNotEmpty) {
      ref.invalidate(mineListProvider);
      for (final mineId in mineIds) {
        ref.invalidate(mineDetailProvider(mineId));
      }
    }
  }

  Set<String> _affectedIds(Map<String, dynamic> result, String key) {
    final affected = result['affected'];
    if (affected is! Map) return const {};
    final values = affected[key];
    if (values is! List) return const {};
    return values
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  void _invalidateConstructionKind(String kind, {String? entityId}) {
    switch (kind) {
      case 'factory':
        ref.invalidate(factoryConstructionProvider);
        ref.invalidate(factoryListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(factoryDetailProvider(entityId));
        }
        break;
      case 'farm':
        ref.invalidate(farmConstructionProvider);
        ref.invalidate(farmListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(farmDetailProvider(entityId));
        }
        break;
      case 'field':
        ref.invalidate(fieldConstructionProvider);
        ref.invalidate(fieldListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(fieldDetailProvider(entityId));
        }
        break;
      case 'mine':
        ref.invalidate(mineConstructionProvider);
        ref.invalidate(mineListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(mineDetailProvider(entityId));
        }
        break;
      case 'arge_center':
        ref.invalidate(playerArgeConstructionProvider);
        ref.invalidate(playerArgeCenterProvider);
        break;
      case 'logistics_company':
        ref.invalidate(playerLogisticsConstructionProvider);
        ref.invalidate(playerLogisticsCompanyProvider);
        break;
      case 'store':
        ref.invalidate(storesListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(storeDetailPageProvider(entityId));
        }
        break;
      case 'warehouse':
        ref.invalidate(warehouseListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          ref.invalidate(warehouseDetailProvider(entityId));
        }
        break;
    }

    ref.invalidate(playerProvider);
  }

  void _invalidateUpgradeKind(String kind, {String? entityId}) {
    switch (kind) {
      case 'factory':
        ref.invalidate(factoryListProvider);
        break;
      case 'farm':
        ref.invalidate(farmListProvider);
        break;
      case 'field':
        ref.invalidate(fieldListProvider);
        break;
      case 'mine':
        ref.invalidate(mineListProvider);
        break;
      case 'warehouse':
        ref.invalidate(warehouseListProvider);
        break;
      case 'store':
        ref.invalidate(storesListProvider);
        break;
      case 'arge_center':
        ref.invalidate(playerArgeCenterProvider);
        break;
    }

    if (entityId != null && entityId.isNotEmpty) {
      switch (kind) {
        case 'factory':
          ref.invalidate(factoryDetailProvider(entityId));
          ref.invalidate(activeFactoryUpgradeProvider(entityId));
          break;
        case 'farm':
          ref.invalidate(farmDetailProvider(entityId));
          ref.invalidate(activeFarmUpgradeProvider(entityId));
          break;
        case 'field':
          ref.invalidate(fieldDetailProvider(entityId));
          ref.invalidate(activeFieldUpgradeProvider(entityId));
          break;
        case 'mine':
          ref.invalidate(mineDetailProvider(entityId));
          ref.invalidate(activeMineUpgradeProvider(entityId));
          break;
        case 'warehouse':
          ref.invalidate(warehouseDetailProvider(entityId));
          ref.invalidate(activeWarehouseUpgradeProvider(entityId));
          break;
        case 'store':
          ref.invalidate(storeDetailPageProvider(entityId));
          break;
        case 'arge_center':
          ref.invalidate(activeArgeCenterUpgradeProvider(entityId));
          break;
      }
    }

    ref.invalidate(anyActiveWarehouseUpgradeProvider);
    ref.invalidate(playerProvider);
  }

  bool _canAutoCompleteTransfer(TransferMapItemModel transfer) {
    final transferType = transfer.transferType.trim().toLowerCase();
    return transferType.isNotEmpty;
  }

  DateTime? _earlier(DateTime? current, DateTime candidate) {
    if (current == null || candidate.isBefore(current)) {
      return candidate;
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(buyerTransferMapProvider, (prev, next) => _onProviderUpdated());
    ref.listen(activeArgeResearchesProvider, (prev, next) => _onProviderUpdated());
    ref.listen(factoryConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(farmConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(fieldConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(mineConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(playerArgeConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(playerLogisticsConstructionProvider, (prev, next) => _onProviderUpdated());
    ref.listen(storesListProvider, (prev, next) => _onProviderUpdated());
    ref.listen(warehouseListProvider, (prev, next) => _onProviderUpdated());
    ref.listen(anyActiveWarehouseUpgradeProvider, (prev, next) => _onProviderUpdated());

    return widget.child;
  }
}

class _CompletionResult {
  const _CompletionResult({
    required this.processedSomething,
    required this.hasErrors,
  });

  final bool processedSomething;
  final bool hasErrors;
}

class _TimedTaskSnapshot {
  const _TimedTaskSnapshot({
    required this.transfers,
    required this.constructions,
    required this.activeUpgrade,
    required this.nextDueAt,
    required this.researches,
  });

  final List<TransferMapItemModel> transfers;
  final List<_TimedConstructionTask> constructions;
  final BuildingUpgradeModel? activeUpgrade;
  final DateTime? nextDueAt;
  final List<ArgeResearchModel> researches;
}

class _TimedConstructionTask {
  const _TimedConstructionTask({
    required this.kind,
    required this.constructionId,
    required this.finishAt,
    this.entityId,
  });

  final String kind;
  final String constructionId;
  final DateTime finishAt;
  final String? entityId;
}
