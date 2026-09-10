import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/paid_slot_unlock_flow.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/production_config_sheet.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_multislot_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';

class MineMultiSlotSection extends ConsumerWidget {
  const MineMultiSlotSection({
    super.key,
    required this.mineId,
    required this.mineTypeId,
    required this.currentSlotCount,
    required this.maxSlotCount,
  });

  final String mineId;
  final String mineTypeId;
  final int currentSlotCount;
  final int maxSlotCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(mineProductionSlotsProvider(mineId));
    final displayedSlotCount = slotsAsync.value?.length ?? currentSlotCount;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.layers, color: AppColors.gold, size: AppIconSizes.regular),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Üretim Slotları',
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$displayedSlotCount / $maxSlotCount slot açık',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (displayedSlotCount < maxSlotCount)
                FilledButton.icon(
                  onPressed: () => _openSlot(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  ),
                  icon: Icon(AppIcons.add, size: AppIconSizes.xSmall),
                  label: const Text('SLOT AÇ'),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          slotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Message(
              text: 'Üretim slotları yüklenemedi: $error',
              color: AppColors.red,
            ),
            data: (slots) => slots.isEmpty
                ? _Message(
                    text: 'Henüz üretim slotu bulunmuyor.',
                    color: AppColors.textMuted,
                  )
                : Column(
                    children: [
                      for (final slot in slots)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: _MineSlotCard(
                            slot: slot,
                            onConfigure: () =>
                                _configureSlot(context, ref, slot, slots),
                            onToggle: slot.isEmpty
                                ? null
                                : () => _toggleSlot(context, ref, slot),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSlot(BuildContext context, WidgetRef ref) async {
    await PaidSlotUnlockFlow.run(
      context: context,
      ref: ref,
      buildingKind: 'mine',
      entityId: mineId,
      onUnlock: () =>
          ref.read(mineMultiSlotActionProvider).addSlot(mineId: mineId),
    );
  }

  Future<void> _toggleSlot(
    BuildContext context,
    WidgetRef ref,
    ProductionSlotContractModel slot,
  ) async {
    final result = await ref.read(mineMultiSlotActionProvider).setSlotActive(
          slotId: slot.id,
          isActive: !slot.isActive,
        );
    if (!context.mounted || result['success'] == true) return;
    AppSnackbar.show(
      context,
      title: 'İşlem başarısız',
      message: result['message']?.toString() ?? 'Slot durumu değiştirilemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _configureSlot(
    BuildContext context,
    WidgetRef ref,
    ProductionSlotContractModel slot,
    List<ProductionSlotContractModel> slots,
  ) async {
    final products = await ref
        .read(mineActionProvider)
        .getSelectableProducts(typeId: mineTypeId);
    if (!context.mounted) return;

    final otherProductIds = slots
        .where((other) => other.id != slot.id && !other.isEmpty)
        .map((other) => other.productId)
        .whereType<String>()
        .toSet();

    await ProductSelectionSheet.show(
      context: context,
      title: 'Slot ${slot.slotIndex} Ürünü',
      options: products.map((selectable) {
        final product = selectable.product;
        final duplicate = otherProductIds.contains(product.id);
        return ProductSelectionOption(
          id: product.id,
          title: product.urunAdi,
          subtitle: 'En fazla ${selectable.maxQualityLevel} kalite',
          iconPath: product.urunIconu,
          badgeText: selectable.hasPreferredBrand ? 'Markalı' : null,
          isDisabled: duplicate,
          disabledReason: duplicate ? 'Bu ürün başka bir slotta seçili' : null,
          onTap: () async {
            Navigator.of(context).pop();
            final brandCompany = ref.read(playerBrandCompanyProvider).value;
            final config = await ProductionConfigSheet.show(
              context: context,
              product: product,
              maxQualityLevel: selectable.maxQualityLevel,
              hasPreferredBrand: selectable.hasPreferredBrand,
              preferredBrandId: selectable.preferredBrandId,
              brandName: brandCompany?.brandName,
              facilityType: 'Maden',
            );
            if (config == null || !context.mounted) return;

            final result = await ref.read(mineMultiSlotActionProvider).configureSlot(
                  mineId: mineId,
                  slotId: slot.id,
                  productId: product.id,
                  qualityLevel: config.qualityLevel,
                  brandId: config.brandId,
                );
            if (!context.mounted) return;
            AppSnackbar.show(
              context,
              title: result['success'] == true ? 'Slot güncellendi' : 'İşlem başarısız',
              message: result['success'] == true
                  ? '${slot.slotIndex}. slot ${product.urunAdi} için hazır.'
                  : result['message']?.toString() ?? 'Ürün atanamadı.',
              type: result['success'] == true
                  ? SnackbarType.success
                  : SnackbarType.error,
            );
          },
        );
      }).toList(),
    );
  }
}

class _MineSlotCard extends StatelessWidget {
  const _MineSlotCard({
    required this.slot,
    required this.onConfigure,
    required this.onToggle,
  });

  final ProductionSlotContractModel slot;
  final VoidCallback onConfigure;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final product = slot.product;
    final accent = slot.isActive ? AppColors.green : AppColors.textMuted;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: product == null
                ? Icon(AppIcons.addBoxOutlined, color: AppColors.gold)
                : BrandedProductImage(
                    fileName: product.urunIconu,
                    productId: product.id,
                    brandId: slot.brandId,
                    fit: BoxFit.contain,
                    showFrame: false,
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot ${slot.slotIndex}',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  product?.urunAdi ?? 'Ürün seçilmedi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!slot.isEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(
                    '${slot.qualityLevel} kalite • ${slot.brandId == SelectableProductionProductModel.defaultBrandId ? 'Brandsiz' : 'Markalı'} • x${slot.boostMultiplier.toStringAsFixed(1)}',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: slot.isEmpty ? 'Ürün seç' : 'Ürünü değiştir',
            onPressed: onConfigure,
            icon: Icon(AppIcons.edit, color: AppColors.gold),
          ),
          if (onToggle != null)
            Switch.adaptive(
              value: slot.isActive,
              onChanged: (_) => onToggle?.call(),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.standardCopyWith(color: color),
      ),
    );
  }
}
