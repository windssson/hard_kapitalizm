import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_detail_page_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreWarehouseDetailScreen extends ConsumerWidget {
  final String storeId;

  const StoreWarehouseDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(storeDetailPageProvider(storeId));
    final currentBrandName = ref.watch(playerBrandCompanyProvider).value?.brandName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: pageAsync.when(
          data: (page) {
            final warehouse = page.storeWarehouse;
            if (warehouse == null) {
              return _buildErrorState('Bu magazaya bagli depo bulunamadi.');
            }

            return Column(
              children: [
                const SecondaryTopBar(title: 'Magaza Deposu'),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.background,
                    onRefresh: () async {
                      ref.invalidate(storeDetailPageProvider(storeId));
                      await ref.read(storeDetailPageProvider(storeId).future);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StoreWarehouseHeaderCard(
                            store: page.store,
                            warehouse: warehouse,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Depo Slotlari',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if (warehouse.slots.isEmpty)
                            _buildEmptyState()
                          else
                            ...warehouse.slots.map(
                              (slot) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _StoreWarehouseSlotCard(
                                  slot: slot,
                                  currentBrandName: currentBrandName,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (error, _) => _buildErrorState(
            'Magaza deposu yuklenemedi.\n$error',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.textMuted,
            size: 28.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            'Magaza deposu bos.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Yeni alimlar ve iade stoklar burada gorunecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}

class _StoreWarehouseHeaderCard extends StatelessWidget {
  final StoreModel store;
  final StoreWarehouseSummaryModel warehouse;

  const _StoreWarehouseHeaderCard({
    required this.store,
    required this.warehouse,
  });

  @override
  Widget build(BuildContext context) {
    final slotCount = warehouse.slots.length;
    final fillRatio = warehouse.capacity > 0
        ? (warehouse.usedCapacity / warehouse.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.blue,
                  size: 26.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouse.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${store.name} icindeki bagli depo',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Kapasite',
                  value:
                      '${warehouse.usedCapacity.toStringAsFixed(1)} / ${warehouse.capacity.toStringAsFixed(1)} m3',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCard(
                  label: 'Urun Cesidi',
                  value: slotCount.toString(),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: fillRatio,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreWarehouseSlotCard extends StatelessWidget {
  final StoreWarehouseSlotSummaryModel slot;
  final String? currentBrandName;

  const _StoreWarehouseSlotCard({
    required this.slot,
    required this.currentBrandName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: BrandedProductImage(
              fileName: slot.productIcon ?? '',
              brandId: slot.brandId,
              brandName:
                  slot.brandId == '00000000-0000-0000-0000-000000000000'
                  ? null
                  : currentBrandName,
              productId: slot.productId,
              fit: BoxFit.contain,
              showFrame: false,
              errorWidget: Icon(
                Icons.inventory_2_outlined,
                color: AppColors.textMuted,
                size: 22.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.productName +
                      (slot.brandId != '00000000-0000-0000-0000-000000000000'
                          ? ' (${currentBrandName ?? 'Markali'})'
                          : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Kalite ${slot.qualityLevel}',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Maliyet: ${AppMoney.full(slot.cost, decimals: 2)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${slot.quantity}',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Adet',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
