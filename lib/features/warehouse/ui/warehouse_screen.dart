import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tümü';

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0: context.go('/home'); break;
      case 2: context.go('/transfer-map'); break;
      case 4: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehouseListProvider);

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
            const SecondaryTopBar(title: 'Depolarım'),
            Expanded(
              child: warehousesAsync.when(
                data: (warehouses) {
                  final filtered = warehouses.where((w) {
                    if (_selectedFilter == 'Aktif') return w.isActive;
                    if (_selectedFilter == 'Pasif') return !w.isActive;
                    return true;
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(warehouseListProvider.future),
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
                          padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 0),
                          sliver: SliverToBoxAdapter(child: _buildFilters()),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 80.h),
                          sliver: filtered.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyState())
                              : SliverList.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final warehouse = filtered[index];
                                    return warehouse.isUnderConstruction
                                        ? _buildConstructionCard(warehouse)
                                        : _buildWarehouseCard(warehouse);
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (error, stack) => Center(child: Text('Hata: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<WarehouseModel> warehouses) {
    final activeCount = warehouses.where((w) => w.isActive).length;
    final totalCapacity = warehouses.fold(0.0, (sum, w) => sum + w.capacity);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGoldLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(Icons.warehouse, AppColors.gold, 'Depo', warehouses.length.toString()),
          Container(width: 1, height: 30.h, color: AppColors.border),
          _buildStatItem(Icons.check_circle, AppColors.green, 'Aktif', activeCount.toString()),
          Container(width: 1, height: 30.h, color: AppColors.border),
          _buildStatItem(Icons.storage, Colors.blueAccent, 'Kapasite', _formatCapacity(totalCapacity)),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp)),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: ['Tümü', 'Aktif', 'Pasif'].map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? AppColors.gold : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWarehouseCard(WarehouseModel warehouse) {
    // Doluluk oranı: (Kullanılan Kapasite / Toplam Kapasite)
    // reservedCapacity burada "kullanılan" anlamında kullanılıyor olabilir (şemaya göre)
    final double ratio = warehouse.capacity > 0 
        ? (warehouse.reservedCapacity / warehouse.capacity).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.go('/warehouses/${warehouse.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.borderGoldLight.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Depo İkonu
                Container(
                  width: 90.w,
                  height: 90.w,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: const CachedAssetImage(fileName: 'depolar.webp', fit: BoxFit.contain),
                ),
                SizedBox(width: 12.w),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: warehouse.name,
                                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: ' - ${warehouse.cityName ?? 'Bilinmiyor'}',
                                    style: TextStyle(color: AppColors.gold, fontSize: 11.sp),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildSmallBadge('Lv. ${warehouse.level}', AppColors.gold),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      _buildProgressBar(ratio),
                      SizedBox(height: 12.h),
                      // Slot Önizlemeleri
                      Row(
                        children: [
                          ...warehouse.slots.take(4).map((slot) => _buildMiniSlot(slot)),
                          if (warehouse.slots.length > 4)
                            Container(
                              margin: EdgeInsets.only(left: 4.w),
                              child: Text('+${warehouse.slots.length - 4}', 
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                            ),
                          if (warehouse.slots.isEmpty)
                            Text('Boş Depo', style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSlot(WarehouseSlotModel slot) {
    if (slot.isEmpty) return const SizedBox();
    return Container(
      width: 32.w,
      height: 32.w,
      margin: EdgeInsets.only(right: 6.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CachedAssetImage(fileName: slot.productIcon ?? 'default', fit: BoxFit.contain),
          Positioned(
            bottom: -8.h,
            right: -4.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(4.r)),
              child: Text(
                _formatQuantity(slot.quantity),
                style: TextStyle(color: Colors.white, fontSize: 7.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double ratio) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Kapasite Kullanımı', style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp)),
            Text('%${(ratio * 100).toInt()}', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold)),
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
              ratio > 0.9 ? AppColors.red : ratio > 0.7 ? Colors.orange : AppColors.green,
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
      child: Text(label, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConstructionCard(WarehouseModel warehouse) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.construction, color: AppColors.gold, size: 28.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warehouse.name, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                Text(warehouse.cityName ?? 'Bilinmeyen Şehir', style: TextStyle(color: AppColors.gold, fontSize: 11.sp)),
                SizedBox(height: 8.h),
                _ConstructionCountdown(
                  finishAt: warehouse.finishAt!,
                  onFinish: () async {
                    await ref.read(warehouseActionProvider).completeConstruction(warehouse.id);
                    ref.invalidate(warehouseListProvider);
                  },
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleQuickFinish(warehouse.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 14.sp),
                Text('Hızlı Bitir', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuickFinish(String id) async {
    // 1. Altın ile süreyi sıfırla
    final finishResult = await ref.read(warehouseActionProvider).finishConstructionWithGold(id);
    
    if (finishResult['success'] == true) {
      // 2. İnşaatı tamamla (Depo kaydını oluştur)
      final completeResult = await ref.read(warehouseActionProvider).completeConstruction(id);
      
      if (completeResult['success'] == true) {
        ref.invalidate(warehouseListProvider);
        if (mounted) {
          AppSnackbar.show(context, title: 'Başarılı', message: 'Depo inşaatı anında tamamlandı!', type: SnackbarType.success);
        }
      } else {
        if (mounted) AppSnackbar.show(context, title: 'Hata', message: completeResult['message'] ?? 'Tamamlama başarısız.', type: SnackbarType.error);
      }
    } else {
      if (mounted) AppSnackbar.show(context, title: 'Hata', message: finishResult['message'] ?? 'Altın işlemi başarısız.', type: SnackbarType.error);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 100.h),
          Icon(Icons.warehouse_outlined, color: AppColors.textMuted, size: 64.sp),
          SizedBox(height: 16.h),
          Text('Henüz bir deponuz bulunmuyor.', style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp)),
        ],
      ),
    );
  }

  String _formatCapacity(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  String _formatQuantity(int qty) {
    if (qty >= 1000) return '${(qty / 1000).toStringAsFixed(1)}k';
    return qty.toString();
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final DateTime finishAt;
  final VoidCallback onFinish;

  const _ConstructionCountdown({required this.finishAt, required this.onFinish});

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
      return const Text('Tamamlanıyor...');
    }

    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final s = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Kalan Süre: $h:$m:$s',
      style: TextStyle(
        color: AppColors.gold,
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
