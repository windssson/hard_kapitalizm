from pathlib import Path


def replace_function(text: str, needle: str, replacement: str) -> str:
    start = text.find(needle)
    if start < 0:
        raise RuntimeError(f"Function not found: {needle}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"Opening brace not found: {needle}")
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[:start] + replacement.rstrip() + "\n\n" + text[i + 1 :]
    raise RuntimeError(f"Closing brace not found: {needle}")


def delete_function(text: str, needle: str) -> str:
    return replace_function(text, needle, "")


factory_path = Path("lib/features/factory/ui/factory_screen.dart")
f = factory_path.read_text()

f = replace_function(
    f,
    "  Widget _buildStatsHeader(",
    r'''  Widget _buildStatsHeader(List<FactoryListItemModel> factories) {
    final activeCount = factories.where((item) => item.factory.isActive).length;
    final totalSlots = factories.fold<int>(
      0,
      (sum, item) => sum + item.factory.maxSlotCount,
    );
    final totalOutputStock = factories.fold<int>(
      0,
      (sum, item) => sum + item.outputStockQuantity,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem(
              AppIcons.factory,
              AppColors.gold,
              'Fabrika',
              factories.length.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.checkCircle,
              AppColors.green,
              'Aktif',
              activeCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.layers,
              AppColors.blue,
              'Slot',
              totalSlots.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.inventory2,
              AppColors.gold,
              'Ürün',
              _formatCompact(totalOutputStock),
            ),
          ],
        ),
      ),
    );
  }''',
)

f = replace_function(
    f,
    "  Widget _buildAdvancedFactoryCard(",
    r'''  Widget _buildAdvancedFactoryCard(FactoryListItemModel item) {
    final factory = item.factory;
    final hasWarning = item.hasWarning;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: AppColors.cardBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.85),
            AppColors.cardBgLight.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: hasWarning
              ? AppColors.warning.withValues(alpha: 0.8)
              : factory.isActive
                  ? AppColors.borderGold.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
          width: hasWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          if (hasWarning)
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (factory.isActive)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.03),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (factory.isActive ? AppColors.gold : AppColors.textMuted)
                      .withValues(alpha: 0.04),
                ),
              ),
            ),
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () => context.push('/factories/${factory.id}'),
                splashColor: AppColors.gold.withValues(alpha: 0.1),
                highlightColor: AppColors.gold.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFactoryImage(item),
                          SizedBox(width: 14.w),
                          Expanded(child: _buildFactoryHeader(item)),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: _buildOutputSection(item)),
                          SizedBox(width: 8.w),
                          Expanded(child: _buildInputSection(item)),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildSlotsSection(item),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }''',
)

f = replace_function(
    f,
    "  Widget _buildFactoryHeader(",
    r'''  Widget _buildFactoryHeader(FactoryListItemModel item) {
    final factory = item.factory;
    final hasWarning = item.hasWarning;
    final warningReason = item.warningReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                factory.name,
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            if (hasWarning && warningReason != null) ...[
              _buildSmallBadge('⚠️ $warningReason', AppColors.warning),
              SizedBox(width: 6.w),
            ],
            _buildSmallBadge(
              factory.isActive ? 'Aktif' : 'Pasif',
              factory.isActive ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              AppIcons.locationOn,
              color: AppColors.gold,
              size: AppIconSizes.xSmall,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                item.cityName,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Seviye ${factory.level}', AppColors.blue),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          item.factoryTypeName,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }''',
)

f = replace_function(
    f,
    "  Widget _buildOutputSection(",
    r'''  Widget _buildOutputSection(FactoryListItemModel item) {
    final ratio = item.outputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.inventory2,
                      color: AppColors.textSecondary,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        'Ürün Deposu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${_formatCompact(item.outputStockQuantity)} adet / ${_formatCompact(item.factory.outputCapacity)} adet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }''',
)

f = replace_function(
    f,
    "  Widget _buildInputSection(",
    r'''  Widget _buildInputSection(FactoryListItemModel item) {
    final ratio = item.inputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.scienceOutlined,
                      color: AppColors.textSecondary,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        'Hammadde Deposu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${_formatCompact(item.inputStockQuantity)} adet / ${_formatCompact(item.factory.inputCapacity)} adet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }''',
)

for name in (
    "  Widget _buildResourceSection(",
    "  Widget _buildFactorySlotPreview(",
    "  Widget _buildLegacyFactoryProduct(",
):
    if name in f:
        f = delete_function(f, name)

factory_slots = r'''  Widget _buildSlotsSection(FactoryListItemModel item) {
    final factory = item.factory;

    ProductionSlotContractModel? slotAt(int slotIndex) {
      for (final slot in item.productionSlots) {
        if (slot.slotIndex == slotIndex) return slot;
      }
      return null;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Üretim Slotları',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildSmallBadge(
                '${factory.currentSlotCount} / ${factory.maxSlotCount} Açık',
                AppColors.gold,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: List.generate(
              factory.maxSlotCount,
              (index) => _buildFactorySlotIcon(
                index: index,
                unlockedCount: factory.currentSlotCount,
                slot: slotAt(index + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorySlotIcon({
    required int index,
    required int unlockedCount,
    required ProductionSlotContractModel? slot,
  }) {
    final isLocked = index >= unlockedCount;
    final hasProduct = slot?.isConfigured == true && slot?.product != null;
    final isActive = slot?.isActive == true;

    return Container(
      width: 48.w,
      height: 48.w,
      padding: EdgeInsets.all(hasProduct ? 4.w : 0),
      decoration: BoxDecoration(
        color: isLocked
            ? AppFx.panelWash(0.3)
            : AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isLocked
              ? AppFx.softOverlay(0.04)
              : hasProduct
                  ? (isActive
                      ? AppColors.green.withValues(alpha: 0.4)
                      : AppColors.textMuted.withValues(alpha: 0.3))
                  : AppColors.borderGold.withValues(alpha: 0.2),
          width: hasProduct ? 1.5 : 1,
        ),
        boxShadow: hasProduct && isActive
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isLocked
          ? Center(
              child: Icon(
                AppIcons.lock,
                color: AppFx.softOverlay(0.24),
                size: AppIconSizes.medium,
              ),
            )
          : hasProduct
              ? CachedAssetImage(
                  fileName: slot!.product!.urunIconu,
                  fit: BoxFit.contain,
                )
              : Center(
                  child: Icon(
                    AppIcons.addCircleOutline,
                    color: AppColors.gold.withValues(alpha: 0.45),
                    size: AppIconSizes.medium,
                  ),
                ),
    );
  }

'''
if "  Widget _buildSlotsSection(FactoryListItemModel item)" not in f:
    marker = "  Widget _buildSmallBadge("
    pos = f.find(marker)
    if pos < 0:
        raise RuntimeError("Factory badge marker missing")
    f = f[:pos] + factory_slots + f[pos:]
factory_path.write_text(f)


mine_path = Path("lib/features/mine/ui/mine_screen.dart")
m = mine_path.read_text()

m = replace_function(
    m,
    "  Widget _buildStatsHeader(",
    r'''  Widget _buildStatsHeader(List<MineListItemModel> mines) {
    final activeCount = mines.where((item) => item.mine.isActive).length;
    final totalSlots = mines.fold<int>(
      0,
      (sum, item) => sum + item.mine.maxSlotCount,
    );
    final totalOutputStock = mines.fold<int>(
      0,
      (sum, item) => sum + item.outputStockQuantity,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem(
              AppIcons.diamondRounded,
              AppColors.gold,
              'Maden',
              mines.length.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.checkCircle,
              AppColors.green,
              'Aktif',
              activeCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.layers,
              AppColors.blue,
              'Slot',
              totalSlots.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.inventory2,
              AppColors.gold,
              'Ürün',
              _formatCompact(totalOutputStock),
            ),
          ],
        ),
      ),
    );
  }''',
)

m = replace_function(
    m,
    "  Widget _buildMineCard(",
    r'''  Widget _buildMineCard(MineListItemModel item) {
    final mine = item.mine;
    final hasWarning = item.hasWarning;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: AppColors.cardBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.85),
            AppColors.cardBgLight.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: hasWarning
              ? AppColors.warning.withValues(alpha: 0.8)
              : mine.isActive
                  ? AppColors.borderGold.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
          width: hasWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          if (hasWarning)
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (mine.isActive)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.03),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (mine.isActive ? AppColors.gold : AppColors.textMuted)
                      .withValues(alpha: 0.04),
                ),
              ),
            ),
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () => context.push('/mines/${mine.id}'),
                splashColor: AppColors.gold.withValues(alpha: 0.1),
                highlightColor: AppColors.gold.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMineImage(item),
                          SizedBox(width: 14.w),
                          Expanded(child: _buildMineHeader(item)),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildOutputSection(item),
                      SizedBox(height: 12.h),
                      _buildSlotsSection(item),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }''',
)

m = replace_function(
    m,
    "  Widget _buildMineHeader(",
    r'''  Widget _buildMineHeader(MineListItemModel item) {
    final mine = item.mine;
    final hasWarning = item.hasWarning;
    final warningReason = item.warningReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                mine.name,
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            if (hasWarning && warningReason != null) ...[
              _buildSmallBadge('⚠️ $warningReason', AppColors.warning),
              SizedBox(width: 6.w),
            ],
            _buildSmallBadge(
              mine.isActive ? 'Aktif' : 'Pasif',
              mine.isActive ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              AppIcons.locationOn,
              color: AppColors.gold,
              size: AppIconSizes.xSmall,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                item.cityName,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Seviye ${mine.level}', AppColors.blue),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          item.mineTypeName,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }''',
)

m = replace_function(
    m,
    "  Widget _buildOutputSection(",
    r'''  Widget _buildOutputSection(MineListItemModel item) {
    final ratio = item.outputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.inventory2,
                      color: AppColors.textSecondary,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        'Ürün Deposu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${_formatCompact(item.outputStockQuantity)} adet / ${_formatCompact(item.mine.outputCapacity)} adet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }''',
)

for name in (
    "  Widget _buildProductSection(",
    "  Widget _buildMineSlotPreview(",
    "  Widget _buildLegacyMineProduct(",
):
    if name in m:
        m = delete_function(m, name)

mine_slots = r'''  Widget _buildSlotsSection(MineListItemModel item) {
    final mine = item.mine;

    ProductionSlotContractModel? slotAt(int slotIndex) {
      for (final slot in item.productionSlots) {
        if (slot.slotIndex == slotIndex) return slot;
      }
      return null;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Üretim Slotları',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildSmallBadge(
                '${mine.currentSlotCount} / ${mine.maxSlotCount} Açık',
                AppColors.gold,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: List.generate(
              mine.maxSlotCount,
              (index) => _buildMineSlotIcon(
                index: index,
                unlockedCount: mine.currentSlotCount,
                slot: slotAt(index + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMineSlotIcon({
    required int index,
    required int unlockedCount,
    required ProductionSlotContractModel? slot,
  }) {
    final isLocked = index >= unlockedCount;
    final hasProduct = slot?.isConfigured == true && slot?.product != null;
    final isActive = slot?.isActive == true;

    return Container(
      width: 48.w,
      height: 48.w,
      padding: EdgeInsets.all(hasProduct ? 4.w : 0),
      decoration: BoxDecoration(
        color: isLocked
            ? AppFx.panelWash(0.3)
            : AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isLocked
              ? AppFx.softOverlay(0.04)
              : hasProduct
                  ? (isActive
                      ? AppColors.green.withValues(alpha: 0.4)
                      : AppColors.textMuted.withValues(alpha: 0.3))
                  : AppColors.borderGold.withValues(alpha: 0.2),
          width: hasProduct ? 1.5 : 1,
        ),
        boxShadow: hasProduct && isActive
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isLocked
          ? Center(
              child: Icon(
                AppIcons.lock,
                color: AppFx.softOverlay(0.24),
                size: AppIconSizes.medium,
              ),
            )
          : hasProduct
              ? CachedAssetImage(
                  fileName: slot!.product!.urunIconu,
                  fit: BoxFit.contain,
                )
              : Center(
                  child: Icon(
                    AppIcons.addCircleOutline,
                    color: AppColors.gold.withValues(alpha: 0.45),
                    size: AppIconSizes.medium,
                  ),
                ),
    );
  }

'''
if "  Widget _buildSlotsSection(MineListItemModel item)" not in m:
    marker = "  Widget _buildSmallBadge("
    pos = m.find(marker)
    if pos < 0:
        raise RuntimeError("Mine badge marker missing")
    m = m[:pos] + mine_slots + m[pos:]
mine_path.write_text(m)


factory_detail = Path("lib/features/factory/ui/factory_detail_screen.dart")
t = factory_detail.read_text()
t = t.replace(
    "'Üretim Hatları',\n                        'Her üretim slotunun ürününü, kalitesini, markasını ve çalışma durumunu ayrı ayrı yönetebilirsin.'",
    "'Üretim Slotları',\n                        'Her slotta ürünü, kaliteyi, markayı ve çalışma durumunu ayrı ayrı yönetebilirsin.'",
)
t = t.replace(
    "'${detail.outputInventories.isNotEmpty ? detail.outputInventories.first.quantity : 0}/${detail.factory.outputCapacity}'",
    "'${detail.totalOutputQuantity}/${detail.factory.outputCapacity}'",
)
t = t.replace(
    "(detail.outputInventories.isNotEmpty\n                            ? detail.outputInventories.first.quantity\n                            : 0)\n                        .toDouble()",
    "detail.totalOutputQuantity.toDouble()",
)
needle = """                      SizedBox(height: 12.h),
                      _buildFactoryInventoryOverview(
                        context,
                        ref,
                        detail,
                      ),"""
replacement = """                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Stok ve Akışlar',
                        'Ortak hammadde ve ürün stoklarını, kapasiteyi ve transfer akışlarını buradan yönetebilirsin.',
                        icon: AppIcons.inventory2Outlined,
                        color: AppColors.blue,
                      ),
                      SizedBox(height: 10.h),
                      _buildFactoryInventoryOverview(
                        context,
                        ref,
                        detail,
                      ),"""
if needle in t:
    t = t.replace(needle, replacement, 1)
factory_detail.write_text(t)


mine_detail = Path("lib/features/mine/ui/mine_detail_screen.dart")
t = mine_detail.read_text()
t = t.replace(
    "'Her slotun kaynağını, kalitesini, markasını ve çalışma durumunu ayrı ayrı yönetebilirsin.'",
    "'Her slotta kaynağı, kaliteyi, markayı ve çalışma durumunu ayrı ayrı yönetebilirsin.'",
)
needle = """                      SizedBox(height: 12.h),
                      _buildMineInventoryOverview(context, ref, detail),"""
replacement = """                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Stok ve Akışlar',
                        'Ortak ürün stoğunu, kapasiteyi ve transfer akışlarını buradan yönetebilirsin.',
                        icon: AppIcons.inventory2Outlined,
                        color: AppColors.blue,
                      ),
                      SizedBox(height: 10.h),
                      _buildMineInventoryOverview(context, ref, detail),"""
if needle in t:
    t = t.replace(needle, replacement, 1)
mine_detail.write_text(t)
