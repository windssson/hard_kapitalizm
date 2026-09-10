from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'Anchor not found in {path}: {old[:80]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def ensure_import(path: Path, anchor: str, imp: str) -> None:
    text = path.read_text(encoding='utf-8')
    if imp in text:
        return
    if anchor not in text:
        raise RuntimeError(f'Import anchor not found in {path}')
    path.write_text(text.replace(anchor, anchor + imp, 1), encoding='utf-8')


factory_provider = Path('lib/features/factory/data/factory_provider.dart')
ensure_import(
    factory_provider,
    "import 'package:hard_kapitalizm/core/models/product_model.dart';\n",
    "import 'package:hard_kapitalizm/core/models/production_slot_model.dart';\n",
)
replace_once(
    factory_provider,
    """      selectedProduct: map['selected_product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['selected_product'] as Map),
            ),
    );
""",
    """      selectedProduct: map['selected_product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['selected_product'] as Map),
            ),
      productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
          .map(
            (row) => ProductionSlotContractModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
    );
""",
)
replace_once(
    factory_provider,
    """    product: map['product'] == null
        ? null
        : ProductModel.fromJson(
            Map<String, dynamic>.from(map['product'] as Map),
          ),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
""",
    """    product: map['product'] == null
        ? null
        : ProductModel.fromJson(
            Map<String, dynamic>.from(map['product'] as Map),
          ),
    productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
        .map(
          (row) => ProductionSlotContractModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
""",
)

mine_provider = Path('lib/features/mine/data/mine_provider.dart')
ensure_import(
    mine_provider,
    "import 'package:hard_kapitalizm/core/models/product_model.dart';\n",
    "import 'package:hard_kapitalizm/core/models/production_slot_model.dart';\n",
)
replace_once(
    mine_provider,
    """        selectedProduct: map['selected_product'] == null
            ? null
            : ProductModel.fromJson(
                Map<String, dynamic>.from(map['selected_product'] as Map),
              ),
      );
""",
    """        selectedProduct: map['selected_product'] == null
            ? null
            : ProductModel.fromJson(
                Map<String, dynamic>.from(map['selected_product'] as Map),
              ),
        productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
            .map(
              (row) => ProductionSlotContractModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
      );
""",
)
replace_once(
    mine_provider,
    """      product: map['product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['product'] as Map),
            ),
      inventories: (map['inventories'] as List<dynamic>? ?? const [])
""",
    """      product: map['product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['product'] as Map),
            ),
      productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
          .map(
            (row) => ProductionSlotContractModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      inventories: (map['inventories'] as List<dynamic>? ?? const [])
""",
)

# Make list-level status checks use the slot source of truth while preserving
# compatibility with older payloads that only expose the legacy mirror.
factory_model = Path('lib/features/factory/models/factory_list_item_model.dart')
replace_once(
    factory_model,
    """  bool get hasSelectedProduct =>
      selectedProduct != null &&
      selectedProduct!.id.isNotEmpty &&
      selectedProduct!.urunAdi.isNotEmpty;
""",
    """  bool get hasSelectedProduct =>
      productionSlots.any((slot) => slot.isConfigured) ||
      (productionSlots.isEmpty &&
          selectedProduct != null &&
          selectedProduct!.id.isNotEmpty &&
          selectedProduct!.urunAdi.isNotEmpty);
""",
)

mine_model = Path('lib/features/mine/models/mine_list_item_model.dart')
replace_once(
    mine_model,
    """  bool get hasSelectedProduct =>
      selectedProduct != null &&
      selectedProduct!.id.isNotEmpty &&
      selectedProduct!.urunAdi.isNotEmpty;
""",
    """  bool get hasSelectedProduct =>
      productionSlots.any((slot) => slot.isConfigured) ||
      (productionSlots.isEmpty &&
          selectedProduct != null &&
          selectedProduct!.id.isNotEmpty &&
          selectedProduct!.urunAdi.isNotEmpty);
""",
)

# Market production-input demand must inspect every active Factory production
# slot. The previous code only looked at the legacy slot-1 selectedProduct.
market = Path('lib/features/market/ui/market_screen.dart')
text = market.read_text(encoding='utf-8')
start = text.find('  for (final f in targetFactories) {')
end = text.find('  for (final f in targetFarms) {', start)
if start < 0 or end < 0:
    raise RuntimeError('Factory production demand block not found')
new_factory_block = r'''  for (final f in targetFactories) {
    if (!f.factory.isActive) continue;

    final activeProducts = <ProductModel>[];
    for (final slot in f.productionSlots) {
      if (slot.isActive && slot.isConfigured && slot.product != null) {
        activeProducts.add(slot.product!);
      }
    }

    // Temporary compatibility for old payloads. New list RPCs include slots.
    if (activeProducts.isEmpty &&
        f.productionSlots.isEmpty &&
        f.selectedProduct != null) {
      activeProducts.add(f.selectedProduct!);
    }
    if (activeProducts.isEmpty) continue;

    final freeCap = math.max(
      0,
      f.factory.inputCapacity - f.inputStockQuantity,
    );
    if (freeCap <= 0) continue;

    // Shared factory input capacity is distributed across all active recipes.
    // Repeated raw materials gain weight from every slot that consumes them.
    final inputWeights = <String, double>{};
    for (final product in activeProducts) {
      final weightedInputs = <String, double>{};
      if ((product.hammadde1Id ?? '').isNotEmpty) {
        weightedInputs[product.hammadde1Id!] =
            (product.hammadde1Miktar ?? 0) > 0
                ? product.hammadde1Miktar!
                : 1.0;
      }
      if ((product.hammadde2Id ?? '').isNotEmpty) {
        weightedInputs[product.hammadde2Id!] =
            (product.hammadde2Miktar ?? 0) > 0
                ? product.hammadde2Miktar!
                : 1.0;
      }
      if ((product.hammadde3Id ?? '').isNotEmpty) {
        weightedInputs[product.hammadde3Id!] =
            (product.hammadde3Miktar ?? 0) > 0
                ? product.hammadde3Miktar!
                : 1.0;
      }
      for (final inputId in product.inputProductIds) {
        weightedInputs.putIfAbsent(inputId, () => 1.0);
      }
      for (final entry in weightedInputs.entries) {
        inputWeights.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }

    final totalWeight = inputWeights.values.fold<double>(
      0,
      (sum, weight) => sum + weight,
    );
    if (totalWeight <= 0) continue;

    for (final entry in inputWeights.entries) {
      final needUnits = (freeCap * (entry.value / totalWeight)).round();
      if (needUnits <= 0) continue;
      grossProductionDemand.update(
        entry.key,
        (value) => value + needUnits,
        ifAbsent: () => needUnits,
      );
    }
  }

'''
text = text[:start] + new_factory_block + text[end:]
market.write_text(text, encoding='utf-8')

print('Part 10 slot payload + market patch applied')
