from pathlib import Path


def ensure_import(path: Path, anchor: str) -> None:
    text = path.read_text(encoding='utf-8')
    imp = "import 'package:hard_kapitalizm/core/widgets/paid_slot_unlock_flow.dart';\n"
    if imp not in text:
        if anchor not in text:
            raise RuntimeError(f'Import anchor missing: {path}')
        text = text.replace(anchor, anchor + imp, 1)
        path.write_text(text, encoding='utf-8')


def replace_method(path: Path, signature: str, replacement: str) -> None:
    text = path.read_text(encoding='utf-8')
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f'Method signature missing in {path}: {signature}')
    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'Method opening brace missing in {path}: {signature}')

    depth = 0
    end = None
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise RuntimeError(f'Method closing brace missing in {path}: {signature}')

    text = text[:start] + replacement.rstrip() + text[end:]
    path.write_text(text, encoding='utf-8')


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Exact block missing in {path}')
    text = text.replace(old, new, 1)
    path.write_text(text, encoding='utf-8')


store_screen = Path('lib/features/store/ui/store_detail_screen.dart')
field_screen = Path('lib/features/field/ui/field_detail_screen.dart')
farm_screen = Path('lib/features/farm/ui/farm_detail_screen.dart')

for p in (store_screen, field_screen, farm_screen):
    ensure_import(
        p,
        "import 'package:hard_kapitalizm/core/widgets/building_upgrade_sheet.dart';\n",
    )

replace_method(
    store_screen,
    "  Future<void> _handleOpenSlot(\n",
    r'''  Future<void> _handleOpenSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final result = await PaidSlotUnlockFlow.run(
      context: context,
      ref: ref,
      buildingKind: 'store',
      entityId: store.id,
      slotLabel: 'raf',
      onUnlock: () => ref.read(storeActionProvider).addStoreSlot(store.id),
    );

    if (!context.mounted || result == null || result['success'] != true) {
      return;
    }

    // add_store_slot already returns store + store_slot patches. MutationSync
    // applies both to the open detail and list providers, so manually appending
    // the slot here would duplicate the new shelf.
    ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
  }
''',
)

replace_method(
    field_screen,
    "  Future<void> _handleAddSlot(\n",
    r'''  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
  ) async {
    await PaidSlotUnlockFlow.run(
      context: context,
      ref: ref,
      buildingKind: 'field',
      entityId: detail.field.id,
      onUnlock: () => ref
          .read(fieldActionProvider)
          .addProductionSlot(detail.field.id),
    );
  }
''',
)

replace_method(
    farm_screen,
    "  Future<void> _handleAddSlot(\n",
    r'''  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
  ) async {
    await PaidSlotUnlockFlow.run(
      context: context,
      ref: ref,
      buildingKind: 'farm',
      entityId: detail.farm.id,
      onUnlock: () => ref
          .read(farmActionProvider)
          .addProductionSlot(detail.farm.id),
    );
  }
''',
)

field_provider = Path('lib/features/field/data/field_provider.dart')
replace_exact(
    field_provider,
    r'''  void addSlot({
    required String fieldId,
    required FieldSlotPreviewModel slot,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    final updatedSlots = [...item.slots, slot];
    final next = [...current];
    next[index] = item.copyWith(
      field: item.field.copyWith(
        currentSlotCount: item.field.currentSlotCount + 1,
      ),
      slots: updatedSlots,
    );
    state = AsyncData(next);
  }
''',
    r'''  void addSlot({
    required String fieldId,
    required FieldSlotPreviewModel slot,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    if (item.slots.any((existing) => existing.id == slot.id)) return;
    final updatedSlots = [...item.slots, slot];
    final nextSlotCount = item.field.currentSlotCount < updatedSlots.length
        ? updatedSlots.length
        : item.field.currentSlotCount;
    final next = [...current];
    next[index] = item.copyWith(
      field: item.field.copyWith(currentSlotCount: nextSlotCount),
      slots: updatedSlots,
    );
    state = AsyncData(next);
  }
''',
)
replace_exact(
    field_provider,
    r'''  void addSlot(ProductionSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    final updatedSlots = [...current.slots, slot];
    state = AsyncData(
      current.copyWith(
        field: current.field.copyWith(
          currentSlotCount: current.field.currentSlotCount + 1,
        ),
        slots: updatedSlots,
      ),
    );
  }
''',
    r'''  void addSlot(ProductionSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    if (current.slots.any((existing) => existing.id == slot.id)) return;
    final updatedSlots = [...current.slots, slot];
    final nextSlotCount = current.field.currentSlotCount < updatedSlots.length
        ? updatedSlots.length
        : current.field.currentSlotCount;
    state = AsyncData(
      current.copyWith(
        field: current.field.copyWith(currentSlotCount: nextSlotCount),
        slots: updatedSlots,
      ),
    );
  }
''',
)

farm_provider = Path('lib/features/farm/data/farm_provider.dart')
replace_exact(
    farm_provider,
    r'''  void addSlot({required String farmId, required FarmSlotPreviewModel slot}) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.farm.id == farmId);
    if (index < 0) return;
    final item = current[index];
    final updatedSlots = [...item.slots, slot];
    final next = [...current];
    next[index] = item.copyWith(
      farm: item.farm.copyWith(
        currentSlotCount: item.farm.currentSlotCount + 1,
      ),
      slots: updatedSlots,
    );
    state = AsyncData(next);
  }
''',
    r'''  void addSlot({required String farmId, required FarmSlotPreviewModel slot}) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.farm.id == farmId);
    if (index < 0) return;
    final item = current[index];
    if (item.slots.any((existing) => existing.id == slot.id)) return;
    final updatedSlots = [...item.slots, slot];
    final nextSlotCount = item.farm.currentSlotCount < updatedSlots.length
        ? updatedSlots.length
        : item.farm.currentSlotCount;
    final next = [...current];
    next[index] = item.copyWith(
      farm: item.farm.copyWith(currentSlotCount: nextSlotCount),
      slots: updatedSlots,
    );
    state = AsyncData(next);
  }
''',
)
replace_exact(
    farm_provider,
    r'''  void addSlot(FarmProductionSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    final updatedSlots = [...current.slots, slot];
    state = AsyncData(
      current.copyWith(
        farm: current.farm.copyWith(
          currentSlotCount: current.farm.currentSlotCount + 1,
        ),
        slots: updatedSlots,
      ),
    );
  }
''',
    r'''  void addSlot(FarmProductionSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    if (current.slots.any((existing) => existing.id == slot.id)) return;
    final updatedSlots = [...current.slots, slot];
    final nextSlotCount = current.farm.currentSlotCount < updatedSlots.length
        ? updatedSlots.length
        : current.farm.currentSlotCount;
    state = AsyncData(
      current.copyWith(
        farm: current.farm.copyWith(currentSlotCount: nextSlotCount),
        slots: updatedSlots,
      ),
    );
  }
''',
)

print('Part 9 paid slot integration applied.')
