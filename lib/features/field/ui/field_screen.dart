import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';

class FieldScreen extends ConsumerStatefulWidget {
  const FieldScreen({super.key});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends ConsumerState<FieldScreen>
    with RouteRefreshMixin<FieldScreen> {
  final int _selectedIndex = -1;
  String _selectedFilter = 'Tumu';

  @override
  void initState() {
    super.initState();
  }

  @override
  void refreshRouteData() {
    ref.invalidate(fieldListProvider);
    ref.invalidate(fieldConstructionProvider);
    ref.read(fieldListProvider.future);
    ref.read(fieldConstructionProvider.future);
  }

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

  Future<void> _refreshAll() async {
    ref.invalidate(fieldListProvider);
    ref.invalidate(fieldConstructionProvider);
    ref.invalidate(playerProvider);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(fieldActionProvider)
        .completeConstruction(constructionId, syncProviders: false);

    ref.invalidate(fieldConstructionProvider);
    ref.invalidate(fieldListProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Ciftlik insaati tamamlanamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    await showExperienceFeedbackFromResult(context, result);
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(fieldActionProvider)
        .finishConstructionWithGold(constructionId, syncProviders: false);

    ref.invalidate(fieldConstructionProvider);
    ref.invalidate(fieldListProvider);
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

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldListProvider);
    final constructionAsync = ref.watch(fieldConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fields/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(Icons.add, size: 16.sp),
        label: Text(
          'YENI CIFTLIK',
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
            const SecondaryTopBar(title: 'Ciftliklerim'),
            Expanded(
              child: fieldsAsync.when(
                data: (fields) => constructionAsync.when(
                  data: (construction) {
                    final filteredFields = _getFilteredFields(fields);
                    return RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                            sliver: SliverToBoxAdapter(
                              child: _buildStatsHeader(fields),
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
                            padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 80.h),
                            sliver: filteredFields.isEmpty
                                ? SliverToBoxAdapter(
                                    child: construction == null
                                        ? _buildEmptyState()
                                        : const SizedBox.shrink(),
                                  )
                                : SliverList.builder(
                                    itemCount: filteredFields.length,
                                    itemBuilder: (context, index) {
                                      return _buildAdvancedFieldCard(
                                        filteredFields[index],
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
                    onRetry: () => ref.refresh(fieldConstructionProvider),
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildErrorState(
                  error,
                  onRetry: () => ref.refresh(fieldListProvider),
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
          title: name?.isNotEmpty == true ? name! : 'Yeni Ciftlik',
          subtitle: 'Ciftlik insaati devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: Icons.grass,
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

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  List<FieldListItemModel> _getFilteredFields(List<FieldListItemModel> fields) {
    return fields.where((item) {
      if (_selectedFilter == 'Aktif') return item.field.isActive;
      if (_selectedFilter == 'Pasif') return !item.field.isActive;
      return true;
    }).toList();
  }

  Widget _buildStatsHeader(List<FieldListItemModel> fields) {
    final activeCount = fields.where((item) => item.field.isActive).length;
    final totalSlots = fields.fold<int>(
      0,
      (sum, item) => sum + item.field.maxSlotCount,
    );
    final totalOutputStock = fields.fold<int>(
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
                  Icons.grass,
                  AppColors.gold,
                  'Toplam Ciftlik',
                  fields.length.toString(),
                  Colors.white,
                ),
              ),
              Container(width: 1.w, height: 36.h, color: AppColors.border.withValues(alpha: 0.5)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: _buildStatItem(
                    Icons.check_circle,
                    AppColors.green,
                    'Aktif Ciftlik',
                    activeCount.toString(),
                    AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Divider(color: AppColors.border.withValues(alpha: 0.3), height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.layers,
                  Colors.blueAccent,
                  'Toplam Slot',
                  totalSlots.toString(),
                  Colors.white,
                ),
              ),
              Container(width: 1.w, height: 36.h, color: AppColors.border.withValues(alpha: 0.5)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: _buildStatItem(
                    Icons.inventory_2,
                    AppColors.gold,
                    'Toplam Urun',
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
    final isSelected = _selectedFilter == label || (label == 'Tümü' && _selectedFilter == 'Tumu');
    return GestureDetector(
      onTap: () {
        setState(() {
          if (label == 'Tümü') {
            _selectedFilter = 'Tumu';
          } else {
            _selectedFilter = label;
          }
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
            color: isSelected ? AppColors.gold : AppColors.border.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
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
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              SizedBox(width: 8.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.goldLight : AppColors.textSecondary,
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
          Icon(Icons.grass, color: AppColors.textMuted, size: 80.sp),
          SizedBox(height: 16.h),
          Text(
            'Henuz bir ciftligin yok.',
            style: AppTextStyles.h2.copyWith(color: AppColors.textMuted),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/fields/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: const BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('ILK CIFTLIGINI KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }



  Widget _buildAdvancedFieldCard(FieldListItemModel item) {
    final field = item.field;
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
          color: field.isActive
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
          if (field.isActive)
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
                  color: (field.isActive ? AppColors.gold : AppColors.textMuted)
                      .withValues(alpha: 0.04),
                  boxShadow: [
                    BoxShadow(
                      color: (field.isActive ? AppColors.gold : AppColors.textMuted)
                          .withValues(alpha: 0.06),
                      blurRadius: 35,
                    ),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/fields/${field.id}'),
                splashColor: AppColors.gold.withValues(alpha: 0.1),
                highlightColor: AppColors.gold.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldImage(item),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: _buildFieldHeader(item),
                          ),
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
  }

  Widget _buildFieldImage(FieldListItemModel item) {
    return Container(
      width: 76.w,
      height: 76.w,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CachedAssetImage(
        fileName: item.fieldTypeIcon,
        fit: BoxFit.contain,
        errorWidget: Icon(
          Icons.grass,
          color: AppColors.green,
          size: 36.sp,
        ),
      ),
    );
  }

  Widget _buildFieldHeader(FieldListItemModel item) {
    final field = item.field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                field.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge(
              field.isActive ? 'Aktif' : 'Pasif',
              field.isActive ? AppColors.green : AppColors.red,
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
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Seviye ${field.level}', Colors.orangeAccent),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          item.fieldTypeName,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.sp,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOutputSection(FieldListItemModel item) {
    final ratio = item.outputStockRatio;
    final color = _getRatioColor(ratio);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                    size: 14.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Urun Deposu',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatCompact(item.outputStockQuantity)} / ${_formatCompact(item.totalOutputCapacity)}',
                style: TextStyle(
                  color: ratio >= 0.9 ? AppColors.red : Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            height: 6.h,
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
                    colors: [
                      color.withValues(alpha: 0.6),
                      color,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsSection(FieldListItemModel item) {
    final field = item.field;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Üretim Slotları',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildSmallBadge(
                '${field.currentSlotCount} / ${field.maxSlotCount} Aktif',
                AppColors.gold,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: List.generate(
              field.maxSlotCount,
              (index) => _buildFieldSlotIcon(
                index: index,
                unlockedCount: field.currentSlotCount,
                slot: index < item.slots.length ? item.slots[index] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSlotIcon({
    required int index,
    required int unlockedCount,
    required FieldSlotPreviewModel? slot,
  }) {
    final isLocked = index >= unlockedCount;
    final hasProduct = slot?.hasProduct == true;

    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.black.withValues(alpha: 0.3)
            : AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isLocked
              ? Colors.white.withValues(alpha: 0.04)
              : hasProduct
                  ? AppColors.green.withValues(alpha: 0.4)
                  : AppColors.borderGold.withValues(alpha: 0.2),
          width: hasProduct ? 1.5 : 1,
        ),
        boxShadow: hasProduct
            ? [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: isLocked
          ? Center(child: Icon(Icons.lock, color: Colors.white24, size: 20.sp))
          : hasProduct
              ? Padding(
                  padding: EdgeInsets.all(6.w),
                  child: CachedAssetImage(
                    fileName: slot!.product!.urunIconu,
                    fit: BoxFit.contain,
                    errorWidget: Icon(
                      Icons.grass,
                      color: AppColors.green,
                      size: 24.sp,
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.add_circle_outline,
                    color: AppColors.gold.withValues(alpha: 0.3),
                    size: 24.sp,
                  ),
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
    if (ratio >= 0.8) return AppColors.green;
    if (ratio >= 0.4) return Colors.orange;
    return AppColors.red;
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
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}
