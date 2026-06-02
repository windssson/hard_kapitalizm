import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with RouteRefreshMixin<MineScreen> {
  final int _selectedIndex = 1;
  String _selectedFilter = 'Tumu';

  @override
  void initState() {
    super.initState();
  }

  @override
  void refreshRouteData() {
    ref.invalidate(mineListProvider);
    ref.invalidate(mineConstructionProvider);
    ref.invalidate(playerProvider);
    ref.read(mineListProvider.future);
    ref.read(mineConstructionProvider.future);
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

  Future<void> _refreshAll() async {
    ref.invalidate(mineListProvider);
    ref.invalidate(mineConstructionProvider);
    ref.invalidate(playerProvider);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .completeConstruction(constructionId, syncProviders: false);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Maden insaati tamamlanamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    await showExperienceFeedbackFromResult(context, result);
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .finishConstructionWithGold(constructionId, syncProviders: false);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);
    ref.invalidate(playerProvider);

    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Tamamlandi',
        message: 'Insaat aninda tamamlandi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yildiz ile bitirme basarisiz oldu.',
      type: SnackbarType.error,
    );
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  List<MineListItemModel> _getFilteredMines(List<MineListItemModel> mines) {
    return mines.where((item) {
      if (_selectedFilter == 'Aktif') return item.mine.isActive;
      if (_selectedFilter == 'Pasif') return !item.mine.isActive;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final minesAsync = ref.watch(mineListProvider);
    final constructionAsync = ref.watch(mineConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mines/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENI MADEN',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Madenlerim'),
            Expanded(
              child: minesAsync.when(
                data: (mines) => constructionAsync.when(
                  data: (construction) {
                    final filteredMines = _getFilteredMines(mines);
                    return RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                            sliver: SliverToBoxAdapter(
                              child: _buildStatsHeader(mines),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 0),
                            sliver: SliverToBoxAdapter(child: _buildFilters()),
                          ),
                          if (construction != null)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 0),
                              sliver: SliverToBoxAdapter(
                                child: _buildConstructionCard(construction),
                              ),
                            ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              10.w,
                              16.h,
                              10.w,
                              80.h,
                            ),
                            sliver: filteredMines.isEmpty
                                ? SliverToBoxAdapter(
                                    child: construction == null
                                        ? _buildEmptyState()
                                        : const SizedBox.shrink(),
                                  )
                                : SliverList.builder(
                                    itemCount: filteredMines.length,
                                    itemBuilder: (context, index) {
                                      return _buildMineCard(
                                        filteredMines[index],
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
                  error: (error, stack) => _buildErrorState(
                    error,
                    onRetry: () => ref.refresh(mineConstructionProvider),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildErrorState(
                  error,
                  onRetry: () => ref.refresh(mineListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(Map<String, dynamic> construction) {
    final finishAtRaw = construction['finish_at'];
    final finishAt = DateTime.tryParse(finishAtRaw?.toString() ?? '');
    final constructionId = construction['id']?.toString();
    final name = construction['name']?.toString();

    if (finishAt == null || constructionId == null) {
      return const SizedBox.shrink();
    }

    final starCost = _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        ConstructionCountdownCard(
          title: name?.isNotEmpty == true ? name! : 'Yeni Maden',
          subtitle: 'Maden insaati devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: Icons.diamond_outlined,
          onFinished: () => _completeConstruction(constructionId),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _finishConstructionWithGold(constructionId),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsHeader(List<MineListItemModel> mines) {
    final activeCount = mines.where((item) => item.mine.isActive).length;
    final assignedCount = mines.where((item) => item.hasSelectedProduct).length;
    final totalOutputStock = mines.fold<int>(
      0,
      (sum, item) => sum + item.outputStockQuantity,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.diamond_rounded,
                  AppColors.gold,
                  'Toplam Maden',
                  mines.length.toString(),
                  Colors.white,
                ),
              ),
              Container(
                width: 1.w,
                height: 36.h,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: _buildStatItem(
                    Icons.check_circle,
                    AppColors.green,
                    'Aktif Maden',
                    activeCount.toString(),
                    AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Divider(
              color: AppColors.border.withValues(alpha: 0.3),
              height: 1,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.category_outlined,
                  Colors.orangeAccent,
                  'Kaynak Secili',
                  assignedCount.toString(),
                  Colors.white,
                ),
              ),
              Container(
                width: 1.w,
                height: 36.h,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: _buildStatItem(
                    Icons.inventory_2,
                    AppColors.gold,
                    'Toplam Stok',
                    _formatCompact(totalOutputStock),
                    Colors.white,
                  ),
                ),
              ),
            ],
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
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16.sp),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tümü', null),
          SizedBox(width: 8.w),
          _buildFilterChip('Aktif', AppColors.green),
          SizedBox(width: 8.w),
          _buildFilterChip('Pasif', AppColors.red),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color? dotColor) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.cardBg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.border.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
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
              SizedBox(width: 8.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.goldLight
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(Icons.diamond_outlined, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text(
            'Henuz bir madenin yok.',
            style: AppTextStyles.h2.copyWith(color: AppColors.textMuted),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/mines/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('ILK MADENINI KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }

  Widget _buildMineCard(MineListItemModel item) {
    final mine = item.mine;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
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
          color: mine.isActive
              ? AppColors.borderGold.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/mines/${mine.id}'),
          borderRadius: BorderRadius.circular(20.r),
          splashColor: AppColors.gold.withValues(alpha: 0.1),
          highlightColor: AppColors.gold.withValues(alpha: 0.05),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMineImage(item),
                    SizedBox(width: 10.w),
                    Expanded(child: _buildMineHeader(item)),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildProductSection(item),
                SizedBox(height: 8.h),
                _buildOutputSection(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMineImage(MineListItemModel item) {
    return Container(
      width: 64.w,
      height: 64.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: CachedAssetImage(
        fileName: item.mineTypeIcon,
        fit: BoxFit.contain,
        errorWidget: Icon(
          Icons.diamond_rounded,
          color: AppColors.gold,
          size: 30.sp,
        ),
      ),
    );
  }

  Widget _buildMineHeader(MineListItemModel item) {
    final mine = item.mine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                mine.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge(
              mine.isActive ? 'Aktif' : 'Pasif',
              mine.isActive ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(Icons.location_on, color: AppColors.gold, size: 12.sp),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                item.cityName,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Lv ${mine.level}', Colors.orangeAccent),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          item.mineTypeName,
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProductSection(MineListItemModel item) {
    final mine = item.mine;
    final product = item.selectedProduct;
    final hasProduct = item.hasSelectedProduct;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: hasProduct
            ? AppColors.cardBgLight.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: hasProduct
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.borderGold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            padding: EdgeInsets.all(hasProduct ? 6.w : 10.w),
            decoration: BoxDecoration(
              color: hasProduct
                  ? AppColors.cardBgLight
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: hasProduct
                    ? AppColors.green.withValues(alpha: 0.3)
                    : AppColors.borderGold.withValues(alpha: 0.2),
              ),
            ),
            child: hasProduct
                ? CachedAssetImage(
                    fileName: product!.urunIconu,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    Icons.add_circle_outline,
                    color: AppColors.gold.withValues(alpha: 0.4),
                    size: 20.sp,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasProduct) ...[
                  Text(
                    'Ürün ayarı gerekli',
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.8),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Ürün seçilmedi',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Detay ekranindan ürün seçerek madeni baslat.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                    ),
                  ),
                ] else ...[
                  Text(
                    product!.urunAdi,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < mine.qualityLevel
                            ? Icons.star
                            : Icons.star_border,
                        color: index < mine.qualityLevel
                            ? AppColors.gold
                            : AppColors.textMuted,
                        size: 10.sp,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasProduct)
                _buildSmallBadge(
                  'Saatlik ${product!.uretimAdedi}',
                  Colors.lightBlueAccent,
                ),
              if (mine.boostMultiplier > 1.0) ...[
                if (hasProduct) SizedBox(height: 4.h),
                _buildSmallBadge(
                  'Boost x${mine.boostMultiplier.toStringAsFixed(1)}',
                  AppColors.gold,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(MineListItemModel item) {
    final ratio = item.outputStockRatio;
    final color = _getRatioColor(ratio);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: AppColors.textSecondary,
                    size: 13.sp,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Cevher stoğu',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatCompact(item.outputStockQuantity)} / ${_formatCompact(item.mine.outputCapacity)}',
                style: TextStyle(
                  color: ratio >= 0.9 ? AppColors.red : Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            height: 5.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3.r),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRatioColor(double ratio) {
    if (ratio >= 0.8) return AppColors.red;
    if (ratio >= 0.4) return Colors.orange;
    return AppColors.green;
  }

  String _formatCompact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget _buildErrorState(Object error, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'Hata: ${error.toString()}',
            style: AppTextStyles.body.copyWith(color: AppColors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
