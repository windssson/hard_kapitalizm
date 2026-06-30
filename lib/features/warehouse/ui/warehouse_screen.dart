import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  final int _selectedIndex = -1;

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/company');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehouseListProvider);
    final currentBrandName = ref.watch(playerBrandCompanyProvider).value?.brandName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/warehouses/new/city'),
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add_home_work, color: Colors.black),
        label: const Text(
          'Yeni Depo',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Depolarim'),
            Expanded(
              child: warehousesAsync.when(
                data: (warehouses) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(warehouseListProvider.notifier).refresh(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildStatsHeader(warehouses),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(5.w, 16.h, 5.w, 80.h),
                          sliver: warehouses.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _buildEmptyState(
                                    hasAnyWarehouse: warehouses.isNotEmpty,
                                  ),
                                )
                              : SliverList.builder(
                                  itemCount: warehouses.length,
                                  itemBuilder: (context, index) {
                                    final warehouse = warehouses[index];
                                    return warehouse.isUnderConstruction
                                        ? _buildConstructionCard(warehouse)
                                        : _buildWarehouseCard(
                                            warehouse,
                                            currentBrandName,
                                          );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildErrorState(error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<WarehouseModel> warehouses) {
    final activeCount = warehouses
        .where((warehouse) => warehouse.isActive)
        .length;
    final totalCapacity = warehouses.fold(
      0.0,
      (sum, warehouse) => sum + warehouse.capacity,
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
              Icons.warehouse,
              AppColors.gold,
              'Depo',
              warehouses.length.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              Icons.check_circle,
              AppColors.green,
              'Aktif',
              activeCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              Icons.storage,
              Colors.blueAccent,
              'Kapasite',
              _formatCapacity(totalCapacity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarehouseCard(
    WarehouseModel warehouse,
    String? currentBrandName,
  ) {
    final filledSlots = warehouse.slots.where((slot) => !slot.isEmpty).toList();
    final usedStockCapacity = filledSlots.fold<double>(
      0,
      (sum, slot) => sum + (slot.quantity * slot.unitVolume),
    );
    final ratio = warehouse.capacity > 0
        ? ((usedStockCapacity + warehouse.reservedCapacity) /
                  warehouse.capacity)
              .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.go('/warehouses/${warehouse.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: AppDecorations.premiumCard(null, 16.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 90.w,
                  height: 90.w,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.32),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: warehouse.typeIcon ?? 'depolar.webp',
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: 90.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.gold,
                        size: 12.sp,
                      ),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          warehouse.cityName ?? 'Bilinmiyor',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          warehouse.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSmallBadge(
                            'Lv. ${warehouse.level}',
                            AppColors.gold,
                          ),
                          SizedBox(width: 6.w),
                          _buildSmallBadge(
                            warehouse.isActive ? 'Aktif' : 'Pasif',
                            warehouse.isActive
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildProgressBar(ratio),
                  SizedBox(height: 12.h),
                  filledSlots.isEmpty
                      ? Text(
                          'Bos Depo',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.sp,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : SizedBox(
                          height: 52.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filledSlots.length,
                            separatorBuilder: (context, index) => SizedBox(width: 8.w),
                            itemBuilder: (context, index) => _buildMiniSlot(
                              filledSlots[index],
                              currentBrandName,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSlot(WarehouseSlotModel slot, String? currentBrandName) {
    if (slot.isEmpty) return const SizedBox();

    return SizedBox(
      width: 50.w,
      height: 50.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderGoldLight.withValues(alpha: 0.18),
              ),
            ),
          ),
          Container(
            width: 40.w,
            height: 40.w,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: BrandedProductImage(
              fileName: slot.productIcon ?? 'default.webp',
              brandId: slot.brandId,
              brandName: _brandNameForSlot(slot, currentBrandName),
              productId: slot.productId,
              fit: BoxFit.contain,
              showFrame: false,
            ),
          ),
        ],
      ),
    );
  }

  String? _brandNameForSlot(WarehouseSlotModel slot, String? currentBrandName) {
    if (slot.brandId == '00000000-0000-0000-0000-000000000000') return null;
    return currentBrandName;
  }

  Widget _buildProgressBar(double ratio) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kapasite Kullanimi',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
            ),
            Text(
              '%${(ratio * 100).toInt()}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6.h,
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio > 0.9
                  ? AppColors.red
                  : ratio > 0.7
                  ? Colors.orange
                  : AppColors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConstructionCard(WarehouseModel warehouse) {
    final finishAt = warehouse.finishAt;
    final starCost = finishAt == null
        ? 0
        : _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: starCost > 0 ? 0 : 16.h),
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.gold, 16.r),
          child: Row(
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.construction,
                  color: AppColors.gold,
                  size: 28.sp,
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
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      warehouse.cityName ?? 'Bilinmeyen Sehir',
                      style: TextStyle(color: AppColors.gold, fontSize: 11.sp),
                    ),
                    SizedBox(height: 8.h),
                    if (finishAt != null)
                      _ConstructionCountdown(
                        finishAt: finishAt,
                        onFinish: () async {
                          final result = await ref
                              .read(warehouseActionProvider)
                              .completeConstruction(warehouse.id);
                          if (result['success'] == true) {
                            await ref
                                .read(warehouseListProvider.notifier)
                                .refresh();
                            ref.invalidate(playerProvider);
                            if (mounted) {
                              await showExperienceFeedbackFromResult(
                                context,
                                result,
                              );
                            }
                          }
                        },
                      )
                    else
                      Text(
                        'Insaat verisi guncelleniyor...',
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
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _handleQuickFinish(warehouse.id, starCost),
            ),
          ),
      ],
    );
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  Future<void> _handleQuickFinish(String id, int starCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Depo Insaatini Bitir',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost yildiz kullanarak depo insaatini aninda tamamlamak istiyor musunuz?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Iptal',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Tamamla',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ref
        .read(warehouseActionProvider)
        .finishConstructionWithGold(id);

    if (result['success'] == true) {
      await ref.read(warehouseListProvider.notifier).refresh();
      ref.invalidate(playerProvider);
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Basarili',
          message: 'Depo insaati aninda tamamlandi!',
          type: SnackbarType.success,
        );
        await showExperienceFeedbackFromResult(context, result);
      }
    } else if (mounted) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Altin ile bitirme islemi basarisiz.',
        type: SnackbarType.error,
      );
    }
  }

  Widget _buildEmptyState({
    required bool hasAnyWarehouse,
  }) {
    final title = hasAnyWarehouse
        ? 'Secili filtreye uygun depo bulunamadi.'
        : 'Henuz deponuz bulunmuyor.';

    return Center(
      child: Column(
        children: [
          SizedBox(height: 100.h),
          Icon(
            Icons.warehouse_outlined,
            color: AppColors.textMuted,
            size: 64.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.red, size: 42.sp),
            SizedBox(height: 12.h),
            Text(
              'Depo listesi yuklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCapacity(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M m3';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K m3';
    return '${value.toStringAsFixed(0)} m3';
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final DateTime finishAt;
  final VoidCallback onFinish;

  const _ConstructionCountdown({
    required this.finishAt,
    required this.onFinish,
  });

  @override
  ConsumerState<_ConstructionCountdown> createState() =>
      _ConstructionCountdownState();
}

class _ConstructionCountdownState
    extends ConsumerState<_ConstructionCountdown> {
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final timeLeft = widget.finishAt.difference(now);

    if (timeLeft.isNegative || timeLeft.inSeconds <= 0) {
      if (!_triggered) {
        _triggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onFinish();
        });
      }
      return const Text('Tamamlaniyor...');
    }

    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final s = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      'Kalan Sure: $h:$m:$s',
      style: TextStyle(
        color: AppColors.gold,
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
