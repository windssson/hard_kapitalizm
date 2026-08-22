import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreDetailHeader extends ConsumerWidget {
  final StoreModel store;
  final VoidCallback? onToggleActiveTap;
  final VoidCallback? onReportTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSellTap;

  const StoreDetailHeader({
    super.key,
    required this.store,
    this.onToggleActiveTap,
    this.onReportTap,
    this.onHistoryTap,
    this.onSellTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSlotCount = store.slots.where((s) => !s.isEmpty).length;
    final isMaxSlots = store.currentSlotCount >= store.maxSlotCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mağaza İkonu & Seviye Rozeti
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 68.w,
                      height: 68.w,
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.cardBgLight,
                            AppColors.cardBg,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: CachedAssetImage(
                        fileName: store.storeType.icon,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      bottom: -4.h,
                      right: -4.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.gold, AppColors.goldDark],
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'Lv.${store.level}',
                          style: AppTextStyles.badgeText.standardCopyWith(
                            color: AppColors.background,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 14.w),

                // Mağaza Bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: AppTextStyles.h2.standardCopyWith(
                          color: AppColors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBgLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.locationOn,
                                  color: AppColors.gold,
                                  size: 11.sp,
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  store.cityName ?? 'Bilinmiyor',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: (store.isActive ? AppColors.green : AppColors.red)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: (store.isActive ? AppColors.green : AppColors.red)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.w,
                                  height: 6.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: store.isActive
                                        ? AppColors.green
                                        : AppColors.red,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  store.isActive ? 'Açık' : 'Kapalı',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: store.isActive
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sağ Üst Aksiyonlar: Satılabilir Ürünler + Menü
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showAcceptedProductsDialog(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.gold,
                          size: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      offset: const Offset(0, 40),
                      color: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: AppColors.borderGold.withValues(alpha: 0.3),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'toggle_active') {
                          onToggleActiveTap?.call();
                        } else if (value == 'report') {
                          onReportTap?.call();
                        } else if (value == 'history') {
                          onHistoryTap?.call();
                        } else if (value == 'sell') {
                          onSellTap?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'toggle_active',
                          child: _HeaderMenuItem(
                            icon: store.isActive
                                ? AppIcons.pauseCircleOutline
                                : AppIcons.playCircleOutline,
                            iconColor:
                                store.isActive ? AppColors.red : AppColors.green,
                            label: store.isActive ? 'Pasif Yap' : 'Aktif Yap',
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'report',
                          child: _HeaderMenuItem(
                            icon: AppIcons.analyticsOutlined,
                            iconColor: AppColors.blue,
                            label: 'Raporu Aç',
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'history',
                          child: _HeaderMenuItem(
                            icon: AppIcons.historyOutlined,
                            iconColor: AppColors.gold,
                            label: 'Geçmişi Aç',
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'sell',
                          child: _HeaderMenuItem(
                            icon: AppIcons.sellOutlined,
                            iconColor: AppColors.red,
                            label: 'Mağazayı Sat',
                          ),
                        ),
                      ],
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          AppIcons.moreVert,
                          color: AppColors.textPrimary,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Alt Mini KPI Şeridi
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderStat(
                  icon: AppIcons.gridView,
                  label: 'Raf Kapasitesi',
                  value: '${store.currentSlotCount}/${store.maxSlotCount} ${isMaxSlots ? '(Maks)' : ''}',
                  color: AppColors.gold,
                ),
                _buildHeaderStat(
                  icon: AppIcons.inventory2Rounded,
                  label: 'Dolu Reyon',
                  value: '$activeSlotCount/${store.currentSlotCount}',
                  color: activeSlotCount == store.currentSlotCount && activeSlotCount > 0
                      ? AppColors.green
                      : AppColors.blue,
                ),
                _buildHeaderStat(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Reyon Hacmi',
                  value: '${store.slotCapacity} adet',
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: 8.5.sp,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAcceptedProductsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final catalogsAsync = ref.watch(staticCatalogsProvider);

            return Dialog(
              backgroundColor: AppColors.transparent,
              child: Container(
                constraints: BoxConstraints(maxHeight: 460.h),
                padding: EdgeInsets.all(16.w),
                decoration: AppDecorations.premiumCard(null, 18.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'SATILABİLİR ÜRÜNLER',
                              style: AppTextStyles.titleGoldBold.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: AppTypography.title,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    catalogsAsync.when(
                      loading: () => SizedBox(
                        height: 100.h,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      error: (err, stack) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Text(
                          'Ürünler yüklenirken hata oluştu.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                      data: (catalogs) {
                        final allProducts = catalogs.products;
                        final matchedStoreType = catalogs.storeTypes.firstWhere(
                          (t) =>
                              t.id.toLowerCase() == store.storeType.id.toLowerCase() ||
                              t.name.toLowerCase() == store.storeType.name.toLowerCase(),
                          orElse: () => store.storeType,
                        );

                        final acceptedIds = (store.storeType.acceptedProductIds.isNotEmpty
                                ? store.storeType.acceptedProductIds
                                : matchedStoreType.acceptedProductIds)
                            .map((id) => id.trim().toUpperCase())
                            .toSet();

                        final acceptedProducts = allProducts
                            .where((p) => acceptedIds.contains(p.id.trim().toUpperCase()))
                            .toList();

                        if (acceptedProducts.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.h),
                            child: Text(
                              'Bu mağazada satılabilir ürün bulunamadı.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        return Flexible(
                          child: GridView.builder(
                            shrinkWrap: true,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8.w,
                              mainAxisSpacing: 8.h,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: acceptedProducts.length,
                            itemBuilder: (context, index) {
                              final product = acceptedProducts[index];
                              return Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBgLight,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: AppColors.borderGoldLight.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32.w,
                                      height: 32.w,
                                      child: CachedAssetImage(
                                        fileName: product.urunIconu,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      product.urunAdi,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.standardCopyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: AppTypography.micro,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _HeaderMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: AppIconSizes.regular),
        SizedBox(width: 8.w),
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.body,
          ),
        ),
      ],
    );
  }
}
