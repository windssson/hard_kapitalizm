import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
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

  Future<void> _reduceConstructionTimeWithAd(String constructionId) async {
    await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'construction_time_reduce',
      resourceId: constructionId,
      onApplyReduction: () => ref
          .read(fieldActionProvider)
          .reduceConstructionTimeWithAd(constructionId),
      successMessage: 'Insaat suresi 10 dakika kisaltildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldListProvider);
    final constructionAsync = ref.watch(fieldConstructionProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fields/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnAccent,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(AppIcons.add, size: AppIconSizes.compact),
        label: Text(
          'YENI CIFTLIK',
          style: AppTextStyles.caption.standardCopyWith(
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.bodySmall,
          ),
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
                            padding: EdgeInsets.fromLTRB(
                              10.w,
                              16.h,
                              10.w,
                              80.h,
                            ),
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
                  loading: () =>
                      Center(child: AppLoadingIndicator(color: AppColors.gold)),
                  error: (error, stack) => _buildErrorState(
                    error,
                    onRetry: () => ref.refresh(fieldConstructionProvider),
                  ),
                ),
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
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
          icon: AppIcons.grass,
          onFinished: () => _completeConstruction(constructionId),
          onReduceTimeWithAd: () =>
              _reduceConstructionTimeWithAd(constructionId),
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
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem(
              AppIcons.grass,
              AppColors.gold,
              'Ciftlik',
              fields.length.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.checkCircle,
              AppColors.green,
              'Aktif',
              activeCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.layers,
              AppColors.blue,
              'Slot',
              totalSlots.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.inventory2,
              AppColors.gold,
              'Urun',
              _formatCompact(totalOutputStock),
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
          child: Icon(icon, color: color, size: AppIconSizes.compact),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
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
    final isSelected =
        _selectedFilter == label ||
        (label == 'Tümü' && _selectedFilter == 'Tumu');
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
            color: isSelected
                ? AppColors.gold
                : AppColors.border.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
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
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
            ],
            Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: isSelected
                    ? AppColors.goldLight
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: AppTypography.body,
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
          Icon(
            AppIcons.grass,
            color: AppColors.textMuted,
            size: AppIconSizes.showcase,
          ),
          SizedBox(height: 16.h),
          Text(
            'Henuz bir ciftligin yok.',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/fields/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: BorderSide(color: AppColors.gold),
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
    final hasWarning = item.hasWarning;

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
          color: hasWarning
              ? AppColors.warning.withValues(alpha: 0.8)
              : field.isActive
                  ? AppColors.borderGold.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
          width: hasWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          if (hasWarning)
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (field.isActive)
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
                      color:
                          (field.isActive
                                  ? AppColors.gold
                                  : AppColors.textMuted)
                              .withValues(alpha: 0.06),
                      blurRadius: 35,
                    ),
                  ],
                ),
              ),
            ),
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () => context.push('/fields/${field.id}'),
                splashColor: AppColors.gold.withValues(alpha: 0.1),
                highlightColor: AppColors.gold.withValues(alpha: 0.05),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldImage(item),
                          SizedBox(width: 14.w),
                          Expanded(child: _buildFieldHeader(item)),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(child: _buildOutputSection(item)),
                          SizedBox(width: 8.w),
                          Expanded(child: _buildInputSection(item)),
                        ],
                      ),
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
        color: AppFx.panelWash(0.3),
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
          AppIcons.grass,
          color: AppColors.green,
          size: AppIconSizes.displayLarge,
        ),
      ),
    );
  }

  Widget _buildFieldHeader(FieldListItemModel item) {
    final field = item.field;
    final hasWarning = item.hasWarning;
    final warningReason = item.warningReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                field.name,
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            if (hasWarning && warningReason != null) ...[
              _buildSmallBadge(
                '⚠️ $warningReason',
                AppColors.warning,
              ),
              SizedBox(width: 6.w),
            ],
            _buildSmallBadge(
              field.isActive ? 'Aktif' : 'Pasif',
              field.isActive ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              AppIcons.locationOn,
              color: AppColors.gold,
              size: AppIconSizes.xSmall,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                item.cityName,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Seviye ${field.level}', AppColors.blue),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          item.fieldTypeName,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOutputSection(FieldListItemModel item) {
    final ratio = item.outputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.inventory2,
                      color: AppColors.textSecondary,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        'Urun Deposu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${_formatCompact(item.outputStockQuantity)} adet / ${_formatCompact(item.totalOutputCapacity)} adet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }

  Widget _buildInputSection(FieldListItemModel item) {
    final ratio = item.inputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.scienceOutlined,
                      color: AppColors.textSecondary,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        'Hammadde Deposu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '${_formatCompact(item.inputStockQuantity)} adet / ${_formatCompact(item.totalInputCapacity)} adet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }

  Widget _buildSlotsSection(FieldListItemModel item) {
    final field = item.field;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Üretim Slotları',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
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
            ? AppFx.panelWash(0.3)
            : AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isLocked
              ? AppFx.softOverlay(0.04)
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
                ),
              ]
            : null,
      ),
      child: isLocked
          ? Center(
              child: Icon(
                AppIcons.lock,
                color: AppFx.softOverlay(0.24),
                size: AppIconSizes.medium,
              ),
            )
          : hasProduct
          ? Padding(
              padding: EdgeInsets.all(6.w),
              child: CachedAssetImage(
                fileName: slot!.product!.urunIconu,
                fit: BoxFit.contain,
                errorWidget: Icon(
                  AppIcons.grass,
                  color: AppColors.green,
                  size: AppIconSizes.large,
                ),
              ),
            )
          : Center(
              child: Icon(
                AppIcons.addCircleOutline,
                color: AppColors.gold.withValues(alpha: 0.3),
                size: AppIconSizes.large,
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
          Icon(
            AppIcons.errorOutline,
            color: AppColors.red,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 16.h),
          Text(
            'Hata: ${error.toString()}',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
