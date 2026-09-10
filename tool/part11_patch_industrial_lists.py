from pathlib import Path


def ensure_import(path: Path, anchor: str, imp: str) -> None:
    text = path.read_text(encoding='utf-8')
    if imp in text:
        return
    if anchor not in text:
        raise RuntimeError(f'import anchor missing in {path}')
    path.write_text(text.replace(anchor, anchor + imp, 1), encoding='utf-8')


def replace_method(path: Path, signature: str, replacement: str) -> None:
    text = path.read_text(encoding='utf-8')
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f'method not found in {path}: {signature}')
    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'opening brace not found in {path}')
    depth = 0
    end = None
    for i in range(brace, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise RuntimeError(f'closing brace not found in {path}')
    path.write_text(text[:start] + replacement.rstrip() + text[end:], encoding='utf-8')


factory = Path('lib/features/factory/ui/factory_screen.dart')
ensure_import(
    factory,
    "import 'package:hard_kapitalizm/core/theme/app_theme.dart';\n",
    "import 'package:hard_kapitalizm/core/models/production_slot_model.dart';\n",
)
replace_method(
    factory,
    '  Widget _buildResourceSection(FactoryListItemModel item) {',
    r'''  Widget _buildResourceSection(FactoryListItemModel item) {
    final configuredSlots = item.productionSlots
        .where((slot) => slot.isConfigured && slot.product != null)
        .toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final hasSlotPayload = item.productionSlots.isNotEmpty;
    final legacyProduct = hasSlotPayload ? null : item.selectedProduct;
    final hasProduction = configuredSlots.isNotEmpty || legacyProduct != null;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: hasProduction
            ? AppColors.cardBgLight.withValues(alpha: 0.3)
            : AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: hasProduction
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.borderGold.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.precisionManufacturingRounded,
                color: hasProduction ? AppColors.green : AppColors.gold,
                size: AppIconSizes.small,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Üretim Hatları',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSmallBadge(
                '${configuredSlots.length}/${item.factory.maxSlotCount}',
                configuredSlots.isNotEmpty ? AppColors.green : AppColors.textMuted,
              ),
              if (item.factory.boostMultiplier > 1.0) ...[
                SizedBox(width: 5.w),
                _buildSmallBadge(
                  'Boost x${item.factory.boostMultiplier.toStringAsFixed(1)}',
                  AppColors.gold,
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          if (configuredSlots.isNotEmpty) ...[
            ...configuredSlots.take(3).map(_buildFactorySlotPreview),
            if (configuredSlots.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  '+${configuredSlots.length - 3} üretim hattı daha',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ] else if (legacyProduct != null) ...[
            _buildLegacyFactoryProduct(item),
          ] else ...[
            Text(
              'Henüz yapılandırılmış üretim hattı yok.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Detay ekranından bir slota ürün atayabilirsin.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorySlotPreview(ProductionSlotContractModel slot) {
    final product = slot.product!;
    final hourly = (product.uretimAdedi *
            (1.0 + (slot.qualityLevel - 1) * 0.20))
        .round();

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.25),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: (slot.isActive ? AppColors.green : AppColors.textMuted)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: CachedAssetImage(
              fileName: product.urunIconu,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot ${slot.slotIndex} • ${product.urunAdi}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'K${slot.qualityLevel} • Saatlik $hourly',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          _buildSmallBadge(
            slot.isActive ? 'Aktif' : 'Pasif',
            slot.isActive ? AppColors.green : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyFactoryProduct(FactoryListItemModel item) {
    final product = item.selectedProduct!;
    final hourly = (product.uretimAdedi *
            (1.0 + (item.factory.qualityLevel - 1) * 0.20))
        .round();
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppFx.panelWash(0.25),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: CachedAssetImage(fileName: product.urunIconu, fit: BoxFit.contain),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '${product.urunAdi} • K${item.factory.qualityLevel} • Saatlik $hourly',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
''',
)

mine = Path('lib/features/mine/ui/mine_screen.dart')
ensure_import(
    mine,
    "import 'package:hard_kapitalizm/core/theme/app_theme.dart';\n",
    "import 'package:hard_kapitalizm/core/models/production_slot_model.dart';\n",
)
replace_method(
    mine,
    '  Widget _buildProductSection(MineListItemModel item) {',
    r'''  Widget _buildProductSection(MineListItemModel item) {
    final configuredSlots = item.productionSlots
        .where((slot) => slot.isConfigured && slot.product != null)
        .toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final hasSlotPayload = item.productionSlots.isNotEmpty;
    final legacyProduct = hasSlotPayload ? null : item.selectedProduct;
    final hasProduction = configuredSlots.isNotEmpty || legacyProduct != null;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: hasProduction
            ? AppColors.cardBgLight.withValues(alpha: 0.3)
            : AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: hasProduction
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.borderGold.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.hardwareRounded,
                color: hasProduction ? AppColors.green : AppColors.gold,
                size: AppIconSizes.small,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Üretim Slotları',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSmallBadge(
                '${configuredSlots.length}/${item.mine.maxSlotCount}',
                configuredSlots.isNotEmpty ? AppColors.green : AppColors.textMuted,
              ),
              if (item.mine.boostMultiplier > 1.0) ...[
                SizedBox(width: 5.w),
                _buildSmallBadge(
                  'Boost x${item.mine.boostMultiplier.toStringAsFixed(1)}',
                  AppColors.gold,
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          if (configuredSlots.isNotEmpty) ...[
            ...configuredSlots.take(3).map(_buildMineSlotPreview),
            if (configuredSlots.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  '+${configuredSlots.length - 3} üretim slotu daha',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ] else if (legacyProduct != null) ...[
            _buildLegacyMineProduct(item),
          ] else ...[
            Text(
              'Henüz yapılandırılmış üretim slotu yok.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Detay ekranından bir slota kaynak atayabilirsin.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMineSlotPreview(ProductionSlotContractModel slot) {
    final product = slot.product!;
    final hourly = (product.uretimAdedi *
            (1.0 + (slot.qualityLevel - 1) * 0.20))
        .round();

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.25),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: (slot.isActive ? AppColors.green : AppColors.textMuted)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: CachedAssetImage(
              fileName: product.urunIconu,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot ${slot.slotIndex} • ${product.urunAdi}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'K${slot.qualityLevel} • Saatlik $hourly',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          _buildSmallBadge(
            slot.isActive ? 'Aktif' : 'Pasif',
            slot.isActive ? AppColors.green : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyMineProduct(MineListItemModel item) {
    final product = item.selectedProduct!;
    final hourly = (product.uretimAdedi *
            (1.0 + (item.mine.qualityLevel - 1) * 0.20))
        .round();
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppFx.panelWash(0.25),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: CachedAssetImage(fileName: product.urunIconu, fit: BoxFit.contain),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '${product.urunAdi} • K${item.mine.qualityLevel} • Saatlik $hourly',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
''',
)

print('Part 11 industrial list UI patch applied')
