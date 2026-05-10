import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'dart:async';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tümü';

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(storesListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/store/new/city'),
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add_business, color: Colors.black),
        label: const Text(
          'Mağaza Kur',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Mağazalarım'),
            Expanded(
              child: storesAsync.when(
                data: (stores) {
                  final filteredStores = stores.where((s) {
                    if (_selectedFilter == 'Aktif') return s.isActive;
                    if (_selectedFilter == 'Pasif') return !s.isActive;
                    return true;
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(storesListProvider.future),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 12.h),
                          _buildStatsHeader(stores),
                          SizedBox(height: 16.h),
                          _buildFilters(),
                          SizedBox(height: 16.h),
                          if (filteredStores.isEmpty)
                            _buildEmptyState()
                          else
                            ...filteredStores.map(
                              (store) => store.isUnderConstruction
                                  ? _buildConstructionCard(store)
                                  : _buildAdvancedStoreCard(store),
                            ),
                          SizedBox(height: 40.h),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => Center(child: Text('Hata: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<StoreModel> stores) {
    final int activeCount = stores.where((s) => s.isActive).length;
    final int totalCapacity = stores.fold(
      0,
      (sum, s) => sum + s.summary.totalCapacity,
    );

    String formattedCapacity = totalCapacity >= 1000
        ? '${(totalCapacity / 1000).toStringAsFixed(1)}K'
        : totalCapacity.toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            Icons.store,
            AppColors.gold,
            'Toplam ',
            stores.length.toString(),
            Colors.white,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.trending_up,
            AppColors.green,
            'Aktif ',
            activeCount.toString(),
            AppColors.green,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.inventory_2,
            Colors.blueAccent,
            'Toplam Kapasite',
            formattedCapacity,
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        _buildFilterChip('Tümü', null),
        SizedBox(width: 8.w),
        _buildFilterChip('Aktif', AppColors.green),
        SizedBox(width: 8.w),
        _buildFilterChip('Pasif', AppColors.red),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color? dotColor) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.gold : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedStoreCard(StoreModel store) {
    return GestureDetector(
      onTap: () => context.go('/store/${store.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.borderGoldLight.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Üst Kısım
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mağaza Resmi (Altın Çerçeveli)
                Container(
                  width: 115.w,
                  height: 115.w,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: store.storeType.icon,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 16.w),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.h),
                      // İsim ve Etiketler Satırı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: store.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' - ${store.cityName ?? 'Bilinmiyor'}',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSmallBadge(
                                'Lv. ${store.level}',
                                AppColors.gold,
                              ),
                              SizedBox(width: 6.w),
                              _buildSmallBadge(
                                store.isActive ? 'Aktif' : 'Pasif',
                                store.isActive
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Progress Bar (Artık burada, ikonun yanında)
                      _buildGradientProgressBar(
                        store.summary.usedCapacityRatio,
                      ),
                      SizedBox(height: 12.h),
                      // Slotlar (Artık burada, Progress Bar'ın altında)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(4, (index) {
                          final activeSlots = store.slots
                              .where((s) => !s.isEmpty)
                              .toList();
                          Widget slotWidget;
                          if (index < activeSlots.length) {
                            slotWidget = _buildAdvancedSlot(activeSlots[index]);
                          } else {
                            slotWidget = _buildEmptyOrLockedSlot(
                              index,
                              store.maxSlotCount,
                            );
                          }
                          return Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: slotWidget,
                          );
                        }),
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

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: AppColors.textMuted),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
          ),
          SizedBox(width: 12.w),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGradientProgressBar(double ratio) {
    return Column(
      children: [
        Container(
          height: 10.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.r),
                    gradient: LinearGradient(
                      colors: [
                        _getRatioColor(ratio).withValues(alpha: 0.6),
                        _getRatioColor(ratio),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '%${(ratio * 100).toInt()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSlot(StoreSlotModel slot) {
    return Container(
      width: 50.w,
      height: 60.h,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // Kalite Badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3.r),
              ),
              child: Text(
                'K${slot.qualityLevel}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 6.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CachedAssetImage(
                fileName: slot.productIcon ?? 'default',
                width: 22.w,
                height: 22.w,
              ),
              SizedBox(height: 2.h),
              Text(
                '${slot.quantity}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrLockedSlot(int index, int maxSlots) {
    bool isLocked = index >= maxSlots;
    return Container(
      width: 50.w,
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Icon(
          isLocked ? Icons.lock : Icons.add,
          color: Colors.white10,
          size: 14.sp,
        ),
      ),
    );
  }

  Color _getRatioColor(double ratio) {
    if (ratio > 0.8) return AppColors.green;
    if (ratio > 0.4) return Colors.orange;
    return AppColors.red;
  }

  Widget _buildConstructionCard(StoreModel store) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. KATMANLI İKON (STACK - Altın Çerçeveli)
          Container(
            width: 115.w,
            height: 115.w,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.8,
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: CachedAssetImage(
                      fileName: store.storeType.icon,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Icon(Icons.construction, color: AppColors.gold, size: 38.sp),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          // 2. BİLGİ VE GERÇEK ZAMANLI PROGRESS ALANI
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: store.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            TextSpan(
                              text: ' - ${store.cityName ?? 'Bilinmeyen'}',
                              style: TextStyle(
                                color: AppColors.gold.withValues(alpha: 0.7),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () => _handleQuickFinish(store.id),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade700,
                              Colors.amber.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 14.sp),
                            SizedBox(width: 4.w),
                            Text(
                              'Hızlı Bitir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // BURASI ANLIK GÜNCELLENEN KISIM
                _ConstructionCountdown(
                  startedAt: store.startedAt ?? DateTime.now(),
                  finishAt: store.finishAt!,
                  onFinish: () async {
                    // Süre bittiğinde dükkanı kur
                    await ref
                        .read(storeActionProvider)
                        .completeConstruction(store.id);
                    // Listeyi yenile
                    ref.invalidate(storesListProvider);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuickFinish(String constructionId) async {
    final result = await ref
        .read(storeActionProvider)
        .finishConstructionWithGold(constructionId);
    if (result['success'] == true) {
      ref.invalidate(storesListProvider);
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Tamamlandı',
          message: 'İnşaat başarıyla tamamlandı!',
          type: SnackbarType.success,
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result['message'] ?? 'Altın ile bitirme işlemi başarısız.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(Icons.store_outlined, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          const Text(
            'Henüz bir mağazan yok.',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ConstructionCountdown extends StatefulWidget {
  final DateTime startedAt;
  final DateTime finishAt;
  final VoidCallback? onFinish;

  const _ConstructionCountdown({
    required this.startedAt,
    required this.finishAt,
    this.onFinish,
  });

  @override
  State<_ConstructionCountdown> createState() => _ConstructionCountdownState();
}

class _ConstructionCountdownState extends State<_ConstructionCountdown> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = widget.finishAt
        .difference(widget.startedAt)
        .inSeconds;
    final elapsed = _now.difference(widget.startedAt).inSeconds;
    final double progress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    final remaining = widget.finishAt.difference(_now);

    String getTimeStr() {
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        if (_timer?.isActive ?? false) {
          _timer?.cancel();
          // Süre bittiğinde callback'i tetikle
          Future.microtask(() => widget.onFinish?.call());
        }
        return 'Tamamlanıyor...';
      }
      final minutes = remaining.inMinutes;
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    final String timeStr = getTimeStr();

    return Column(
      children: [
        // İlerleme Çubuğu ve Yüzde
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.gold,
                  ),
                  minHeight: 8.h,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              '%${(progress * 100).toInt()}',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // Kalan Süre
        Row(
          children: [
            Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              'Kalan: ',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            Text(
              timeStr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

extension on Widget {
  Widget withHeight(double height) => SizedBox(height: height, child: this);
}
