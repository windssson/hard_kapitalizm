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
    final slots = slotsAsync.value ?? const <ProductionSlotContractModel>[];
    final displayedSlotCount = slots.length > currentSlotCount
        ? slots.length
        : currentSlotCount;
    final brandName = ref.watch(playerBrandCompanyProvider).value?.brandName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CountBadge(label: '$displayedSlotCount / $maxSlotCount Açık'),
            const Spacer(),
            if (displayedSlotCount < maxSlotCount)
              FilledButton.icon(
                onPressed: () => _openSlot(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 9.h,
                  ),
                ),
                icon: Icon(AppIcons.add, size: AppIconSizes.xSmall),
                label: const Text('SLOT AÇ'),
              ),
          ],
        ),
        SizedBox(height: 10.h),
        slotsAsync.when(
          loading: () => Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18.h),
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => _Message(
            text: 'Üretim slotları yüklenemedi: $error',
            color: AppColors.red,
          ),
          data: (loadedSlots) {
            if (loadedSlots.isEmpty) {
              return _Message(
                text: 'Henüz üretim slotu bulunmuyor.',
                color: AppColors.textMuted,
              );
            }
            final ordered = [...loadedSlots]
              ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
            return Column(
              children: [
                for (final slot in ordered)
                  _MineSlotCard(
                    slot: slot,
                    brandName: brandName,
                    onConfigure: () =>
                        _configureSlot(context, ref, slot, ordered),
                    onToggle: slot.isEmpty
                        ? null
                        : () => _toggleSlot(context, ref, slot),
                  ),
              ],
            );
          },
        ),
      ],
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
    final result = await ref
        .read(mineMultiSlotActionProvider)
        .setSlotActive(slotId: slot.id, isActive: !slot.isActive);
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

            final result = await ref
                .read(mineMultiSlotActionProvider)
                .configureSlot(
                  mineId: mineId,
                  slotId: slot.id,
                  productId: product.id,
                  qualityLevel: config.qualityLevel,
                  brandId: config.brandId,
                );
            if (!context.mounted) return;
            AppSnackbar.show(
              context,
              title: result['success'] == true
                  ? 'Slot güncellendi'
                  : 'İşlem başarısız',
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
    required this.brandName,
    required this.onConfigure,
    required this.onToggle,
  });

  final ProductionSlotContractModel slot;
  final String? brandName;
  final VoidCallback onConfigure;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final product = slot.product;
    final isBranded =
        slot.brandId != SelectableProductionProductModel.defaultBrandId;
    final activeColor = slot.isActive ? AppColors.green : AppColors.red;
    final title = slot.isEmpty
        ? 'Boş Slot ${slot.slotIndex}'
        : '${product?.urunAdi ?? slot.productId ?? 'Bilinmeyen Kaynak'}${isBranded ? ' (${brandName ?? 'Markalı'})' : ''}';
    final hourly = product == null
        ? 0
        : (product.uretimAdedi *
                  (1.0 + (slot.qualityLevel - 1) * 0.20) *
                  slot.boostMultiplier)
              .round();

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(13.w),
      decoration: AppDecorations.premiumCard(
        slot.isActive ? AppColors.green : null,
        18.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 66.w,
                height: 66.w,
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.3),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: slot.isEmpty
                        ? AppFx.softOverlay(0.10)
                        : activeColor.withValues(alpha: 0.35),
                    width: 1.2.w,
                  ),
                ),
                child: product == null
                    ? Icon(
                        AppIcons.addCircleOutline,
                        color: AppColors.textMuted,
                        size: AppIconSizes.large,
                      )
                    : BrandedProductImage(
                        fileName: product.urunIconu,
                        productId: product.id,
                        brandId: slot.brandId,
                        brandName: isBranded ? brandName : null,
                        fit: BoxFit.contain,
                        showFrame: false,
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _IndexBadge(index: slot.slotIndex),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.title,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        _StatusTag(
                          text: slot.isActive ? 'AKTİF' : 'PASİF',
                          color: activeColor,
                        ),
                        SizedBox(width: 4.w),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          offset: const Offset(0, 40),
                          color: AppColors.cardBgLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.3),
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'product') {
                              onConfigure();
                            } else if (value == 'toggle') {
                              onToggle?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'product',
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.category,
                                    color: AppColors.gold,
                                    size: AppIconSizes.regular,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    slot.isEmpty
                                        ? 'Kaynak Seç'
                                        : 'Kaynağı Değiştir',
                                  ),
                                ],
                              ),
                            ),
                            if (onToggle != null)
                              PopupMenuItem<String>(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      slot.isActive
                                          ? AppIcons.stopCircle
                                          : AppIcons.playCircle,
                                      color: slot.isActive
                                          ? AppColors.red
                                          : AppColors.green,
                                      size: AppIconSizes.regular,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      slot.isActive
                                          ? 'Üretimi Durdur'
                                          : 'Üretime Başla',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          child: Container(
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: AppFx.softOverlay(0.05),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: AppFx.softOverlay(0.06),
                              ),
                            ),
                            child: Icon(
                              AppIcons.moreVert,
                              color: AppColors.textMuted,
                              size: AppIconSizes.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    if (slot.isEmpty)
                      Text(
                        'Slot boş. Kaynak seçerek üretimi başlatabilirsin.',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.bodySmall,
                        ),
                      )
                    else
                      Row(
                        children: [
                          _QualityStars(level: slot.qualityLevel),
                          SizedBox(width: 6.w),
                          _QualityBadge(level: slot.qualityLevel),
                          if (slot.boostMultiplier > 1.0) ...[
                            SizedBox(width: 6.w),
                            _StatusTag(
                              text:
                                  'x${slot.boostMultiplier.toStringAsFixed(1)}',
                              color: AppColors.gold,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppFx.softOverlay(0.025),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppFx.softOverlay(0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      icon: AppIcons.schedule,
                      label: 'Üretim Hızı',
                      value: '+$hourly ad/sa',
                      color: AppColors.green,
                    ),
                  ),
                  Container(
                    width: 1.w,
                    height: 26.h,
                    color: AppFx.softOverlay(0.12),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _StatCell(
                      icon: AppIcons.layersOutlined,
                      label: 'Slot',
                      value: '${slot.slotIndex}',
                      color: AppColors.blue,
                    ),
                  ),
                  Container(
                    width: 1.w,
                    height: 26.h,
                    color: AppFx.softOverlay(0.12),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _StatCell(
                      icon: slot.isActive
                          ? AppIcons.checkCircle
                          : AppIcons.pauseCircleOutline,
                      label: 'Durum',
                      value: slot.isActive ? 'Çalışıyor' : 'Bekliyor',
                      color: activeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: AppIconSizes.small),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  color: color,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QualityStars extends StatelessWidget {
  const _QualityStars({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(right: 1.w),
          child: Icon(
            index < level ? AppIcons.star : AppIcons.starBorder,
            color: index < level ? AppColors.gold : AppColors.textMuted,
            size: AppIconSizes.xxSmall,
          ),
        );
      }),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'K$level',
        style: AppTextStyles.caption.standardCopyWith(
          color: AppColors.gold,
          fontSize: AppTypography.micro,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.08),
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: AppFx.softOverlay(0.14)),
      ),
      child: Text(
        '#$index',
        style: AppTextStyles.caption.standardCopyWith(
          color: AppColors.textSecondary,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: AppColors.gold,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
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
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.standardCopyWith(color: color),
      ),
    );
  }
}
