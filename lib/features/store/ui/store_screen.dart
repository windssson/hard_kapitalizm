import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with RouteRefreshMixin<StoreScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tumu';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshRouteData());
  }

  @override
  void refreshRouteData() {
    ref.invalidate(storesListProvider);
    ref.read(storesListProvider.future);
  }

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
          'Magaza Kur',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Magazalarim'),
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
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(6.w, 12.h, 6.w, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildStatsHeader(stores),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(6.w, 16.h, 6.w, 0),
                          sliver: SliverToBoxAdapter(child: _buildFilters()),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(6.w, 16.h, 6.w, 40.h),
                          sliver: filteredStores.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyState())
                              : SliverList.builder(
                                  itemCount: filteredStores.length,
                                  itemBuilder: (context, index) {
                                    final store = filteredStores[index];
                                    return TweenAnimationBuilder<double>(
                                      duration: Duration(milliseconds: 300 + (index * 100).clamp(0, 600)),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(begin: 0, end: 1),
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, 30 * (1 - value)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: store.isUnderConstruction
                                          ? _buildConstructionCard(store)
                                          : _buildAdvancedStoreCard(store),
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
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            Icons.store,
            AppColors.gold,
            'Toplam',
            stores.length.toString(),
            AppColors.textPrimary,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.trending_up,
            AppColors.green,
            'Aktif',
            activeCount.toString(),
            AppColors.green,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            Icons.inventory_2,
            Colors.blueAccent,
            'Kapasite',
            formattedCapacity,
            AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  String _formatCompactValue(num value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  double _calculateStoreStockCost(StoreModel store) {
    final summaryCost = store.summary.totalStockCostValue;
    if (summaryCost != null && summaryCost > 0) {
      return summaryCost;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + ((slot.cost ?? 0) * slot.quantity),
    );
  }

  double _calculateStoreStockSaleValue(StoreModel store) {
    final summarySaleValue = store.summary.totalStockSaleValue;
    if (summarySaleValue != null && summarySaleValue > 0) {
      return summarySaleValue;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + ((slot.price ?? 0) * slot.quantity),
    );
  }

  double _calculatePendingSaleValue(StoreModel store) {
    final summaryPending = store.summary.pendingSaleTotal;
    if (summaryPending != null && summaryPending > 0) {
      return summaryPending;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + (slot.pendingSale ?? 0),
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
        _buildFilterChip('Tumu', null),
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
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(StoreModel store) {
    final starCost = _calculateStarCost(store.finishAt!.toLocal());

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: starCost > 0 ? 0 : 10.h),
          padding: EdgeInsets.all(8.w),
          decoration: AppDecorations.premiumCard(AppColors.gold.withValues(alpha: 0.4), 24.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                    Icon(
                      Icons.construction,
                      color: AppColors.gold,
                      size: 38.sp,
                    ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: store.name,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              
                            ),
                          ),
                          TextSpan(
                            text: ' - ${store.cityName ?? "Bilinmeyen"}',
                            style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.7),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _ConstructionCountdown(
                      startedAt: store.startedAt ?? DateTime.now(),
                      finishAt: store.finishAt!,
                      onFinish: () async {
                        await ref
                            .read(storeActionProvider)
                            .completeConstruction(store.id);
                        ref.invalidate(storesListProvider);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _handleQuickFinish(store.id, starCost),
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

  Future<void> _handleQuickFinish(String constructionId, int starCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Insaati Bitir',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost ⭐ yildiz kullanarak insaati aninda tamamlamak istiyor musunuz?',
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .finishConstructionWithGold(constructionId);
    if (result['success'] == true) {
      ref.invalidate(storesListProvider);
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Tamamlandi',
          message: 'Insaat basariyla tamamlandi!',
          type: SnackbarType.success,
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result['message'] ?? 'Altin ile bitirme islemi basarisiz.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Widget _buildAdvancedStoreCard(StoreModel store) {
    final stockCost = _calculateStoreStockCost(store);
    final stockSaleValue = _calculateStoreStockSaleValue(store);
    final pendingSaleValue = _calculatePendingSaleValue(store);

    return GestureDetector(
      onTap: () => context.go('/store/${store.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: AppDecorations.premiumCard(null, 20.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN
            Column(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12.r),
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
                SizedBox(height: 6.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: AppColors.gold, size: 10.sp),
                    SizedBox(width: 2.w),
                    Text(
                      store.cityName ?? 'Bilinmiyor',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 12.w),
            // MIDDLE & RIGHT COLUMNS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // MIDDLE TOP
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            _buildSmallBadge('Lv. ${store.level}', AppColors.gold),
                          ],
                        ),
                      ),
                      // RIGHT TOP
                      _buildSmallBadge(
                        store.isActive ? 'Aktif' : 'Pasif',
                        store.isActive ? AppColors.green : AppColors.red,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _buildInfoPill(
                        icon: Icons.grid_view_rounded,
                        label: 'Slot',
                        value: '${store.currentSlotCount}/${store.maxSlotCount}',
                        color: AppColors.gold,
                      ),
                      _buildInfoPill(
                        icon: Icons.inventory_2_rounded,
                        label: 'Doluluk',
                        value: '%${(store.summary.usedCapacityRatio * 100).round()}',
                        color: store.summary.usedCapacityRatio >= 0.85
                            ? AppColors.red
                            : AppColors.green,
                      ),
                      _buildInfoPill(
                        icon: Icons.schedule_rounded,
                        label: 'Bekleyen',
                        value: _formatCompactValue(pendingSaleValue),
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildValueColumn(
                            'Maliyet',
                            'TL ${_formatCompactValue(stockCost)}',
                            AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: _buildValueColumn(
                            'Liste Degeri',
                            'TL ${_formatCompactValue(stockSaleValue)}',
                            AppColors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildValueColumn(
                            'Bos Kap.',
                            _formatCompactValue(
                              store.summary.availableCapacity,
                            ),
                            AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (store.slots.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: store.slots.map((slot) => _buildSlotItem(slot)).toList(),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            '$label: $value',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotItem(StoreSlotModel slot) {
    final double fillRatio = slot.capacity > 0 ? (slot.quantity / slot.capacity).clamp(0.0, 1.0) : 0.0;
    
    // Color transitions from red to green based on fill ratio
    final Color progressColor = Color.lerp(AppColors.red, AppColors.green, fillRatio) ?? AppColors.green;

    return Container(
      margin: EdgeInsets.only(right: 8.w),
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderGoldLight.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Fill Progress Background
            if (!slot.isEmpty && slot.isActive)
              FractionallySizedBox(
                heightFactor: fillRatio,
                widthFactor: 1.0,
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: progressColor.withValues(alpha: 0.3),
                ),
              ),
            // Bottom solid line indicating it's a progress bar
            if (!slot.isEmpty && slot.isActive)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 3.h,
                child: FractionallySizedBox(
                  widthFactor: fillRatio,
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressColor,
                      boxShadow: [
                        BoxShadow(color: progressColor.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, -1)),
                      ]
                    )
                  ),
                ),
              ),
            // Icon
            Center(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: slot.isEmpty 
                  ? Icon(Icons.add, color: AppColors.textMuted.withValues(alpha: 0.3), size: 20.sp) 
                  : CachedAssetImage(fileName: slot.productIcon ?? 'default.webp'),
              ),
            ),
            // Pasif indicator
            if (!slot.isEmpty && !slot.isActive)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Icon(Icons.pause, color: AppColors.red, size: 20.sp),
                ),
              ),
          ],
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(Icons.store_outlined, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          const Text(
            'Henuz bir magazan yok.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final DateTime startedAt;
  final DateTime finishAt;
  final VoidCallback? onFinish;

  const _ConstructionCountdown({
    required this.startedAt,
    required this.finishAt,
    this.onFinish,
  });

  @override
  ConsumerState<_ConstructionCountdown> createState() =>
      _ConstructionCountdownState();
}

class _ConstructionCountdownState extends ConsumerState<_ConstructionCountdown> {
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalDuration = widget.finishAt.difference(widget.startedAt).inSeconds;
    final elapsed = now.difference(widget.startedAt).inSeconds;
    final double progress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    final remaining = widget.finishAt.difference(now);

    String getTimeStr() {
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        if (!_triggered) {
          _triggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onFinish?.call();
          });
        }
        return 'Tamamlaniyor...';
      }
      final minutes = remaining.inMinutes;
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    final String timeStr = getTimeStr();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
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
                color: AppColors.textPrimary,
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
