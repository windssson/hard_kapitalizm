import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/arge/data/arge_provider.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';
import 'package:hard_kapitalizm/features/arge/ui/widgets/live_active_research_card.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class ArgeScreen extends ConsumerStatefulWidget {
  const ArgeScreen({super.key});

  @override
  ConsumerState<ArgeScreen> createState() => _ArgeScreenState();
}

class _ArgeScreenState extends ConsumerState<ArgeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedUnit = 'TUMU';
  String _selectedScope = 'TUMU';
  bool _isUpgrading = false;
  bool _isCenterSubmitting = false;

  static const _unitFilters = [
    ('TUMU', 'Tumu'),
    ('FABRIKA', 'Fabrika'),
    ('TARLA', 'Tarla'),
    ('CIFTLIK', 'Çiftlik'),
    ('MADEN', 'Maden'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavSelected(int index) {
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

  Future<void> _refresh() async {
    await ref.read(argeActionProvider).completeDueBuildingUpgrades();
    if (!mounted) return;
    _refreshCenterEcosystem();
  }

  void _refreshCenterEcosystem([String? centerId]) {
    ref.invalidate(argeProductsProvider);
    ref.invalidate(playerArgeCenterProvider);
    ref.invalidate(playerArgeConstructionProvider);
    ref.invalidate(activeArgeResearchesProvider);
    ref.invalidate(activeArgeResearchProvider);
    if (centerId != null && centerId.isNotEmpty) {
      ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
    }
  }

  void _showNewResearchProductSelection(
    BuildContext context,
    List<ArgeProductModel> allProducts,
    int playerLevel,
    double playerCash,
    int activeResearchCount,
    int maxConcurrentResearches,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) {
        return _NewResearchProductSelectionSheet(
          allProducts: allProducts,
          playerLevel: playerLevel,
          playerCash: playerCash,
          activeResearchCount: activeResearchCount,
          maxConcurrentResearches: maxConcurrentResearches,
          onSelect: (product) {
            Navigator.pop(context);
            _showUpgradeSheet(
              product,
              playerLevel: playerLevel,
              playerCash: playerCash,
              hasAvailableResearchSlot:
                  activeResearchCount < maxConcurrentResearches,
              allProducts: allProducts,
            );
          },
        );
      },
    );
  }

  List<ArgeProductModel> _filter(
    List<ArgeProductModel> products, {
    required int playerLevel,
    required double playerCash,
    required int activeResearchCount,
    required int maxConcurrentResearches,
  }) {
    final hasFreeSlot = activeResearchCount < maxConcurrentResearches;
    return products.where((product) {
      if (product.currentQualityLevel <= 0) return false;

      final matchesSearch =
          _searchQuery.isEmpty ||
          product.urunAdi.toLowerCase().contains(_searchQuery);
      final matchesUnit =
          _selectedUnit == 'TUMU' || product.uretimBirimi == _selectedUnit;

      bool matchesScope = true;
      if (_selectedScope == 'URETTIKLERIM') {
        matchesScope = product.isProduced;
      } else if (_selectedScope == 'ARASTIRILABILIR') {
        matchesScope =
            !product.isMaxQuality &&
            product.canUpgrade(
              playerLevel: playerLevel,
              playerCash: playerCash,
              allProducts: products,
            ) &&
            hasFreeSlot;
      }
      return matchesSearch && matchesUnit && matchesScope;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ArgeResearchModel?>>(activeArgeResearchProvider, (
      previous,
      next,
    ) {
      final research = next.value;
      if (research != null && research.isDone) {
        ref.read(argeActionProvider).completeResearch(research.id);
      }
    });

    final centerAsync = ref.watch(playerArgeCenterProvider);
    final centerId = centerAsync.value?.id ?? '';

    ref.listen<AsyncValue<BuildingUpgradeModel?>>(
      activeArgeCenterUpgradeProvider(centerId),
      (previous, next) {
        final upgrade = next.value;
        if (upgrade != null && upgrade.finishAt.isBefore(DateTime.now())) {
          ref.read(argeActionProvider).completeDueBuildingUpgrades();
        }
      },
    );

    final productsAsync = ref.watch(argeProductsProvider);
    final researchesAsync = ref.watch(activeArgeResearchesProvider);
    final playerAsync = ref.watch(playerProvider);
    final constructionAsync = ref.watch(playerArgeConstructionProvider);
    final player = playerAsync.value;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      floatingActionButton: centerAsync.maybeWhen(
        data: (center) {
          if (center == null) return null;
          return productsAsync.maybeWhen(
            data: (products) => FloatingActionButton.extended(
              onPressed: () => _showNewResearchProductSelection(
                context,
                products,
                player?.level ?? 1,
                (player?.cash ?? 0).toDouble(),
                researchesAsync.value?.length ?? 0,
                center.maxConcurrentResearches,
              ),
              backgroundColor: AppColors.gold,
              icon: Icon(AppIcons.science, color: AppColors.textOnAccent),
              label: Text(
                'Araştırma Yap',
                style: AppTextStyles.button.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            orElse: () => null,
          );
        },
        orElse: () => null,
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'AR-GE Merkezi'),
            Expanded(
              child: centerAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, _) => _buildError(error),
                data: (center) {
                  if (center == null) {
                    return constructionAsync.when(
                      loading: () => Center(
                        child: AppLoadingIndicator(color: AppColors.gold),
                      ),
                      error: (error, _) => _buildError(error),
                      data: (construction) {
                        if (construction != null) {
                          return _buildConstructionState(construction);
                        }

                        return playerAsync.when(
                          loading: () => Center(
                            child: AppLoadingIndicator(color: AppColors.gold),
                          ),
                          error: (error, _) => _buildError(error),
                          data: (player) => _buildSetupState(player),
                        );
                      },
                    );
                  }

                  final activeUpgradeAsync = ref.watch(
                    activeArgeCenterUpgradeProvider(center.id),
                  );

                  return productsAsync.when(
                    loading: () => Center(
                      child: AppLoadingIndicator(color: AppColors.gold),
                    ),
                    error: (error, _) => _buildError(error),
                    data: (products) => RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppColors.gold,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                              child: _buildStatsBanner(
                                center,
                                researchesAsync.value?.length ?? 0,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _buildCenterActions(
                              center,
                              activeUpgradeAsync.value,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: activeUpgradeAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (upgrade) => upgrade == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        10.w,
                                        12.h,
                                        10.w,
                                        0,
                                      ),
                                      child: _ActiveArgeUpgradeCard(
                                        upgrade: upgrade,
                                        onFinishWithGold: () =>
                                            _finishCenterUpgradeWithGold(
                                              upgrade,
                                            ),
                                        onReduceTimeWithAd: () =>
                                            _reduceCenterUpgradeTimeWithAd(
                                              upgrade,
                                            ),
                                        calculateStarCost:
                                            _calculateUpgradeStarCost,
                                        formatCountdown: _formatCountdown,
                                      ),
                                    ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: researchesAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (e, s) => Container(
                                padding: EdgeInsets.all(10.w),
                                margin: EdgeInsets.fromLTRB(
                                  10.w,
                                  12.h,
                                  10.w,
                                  0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppColors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Araştırmalar yüklenirken hata oluştu: $e',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.red,
                                    fontSize: AppTypography.bodySmall,
                                  ),
                                ),
                              ),
                              data: (researches) => researches.isEmpty
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        10.w,
                                        12.h,
                                        10.w,
                                        0,
                                      ),
                                      child: Column(
                                        children: [
                                          for (final research
                                              in researches) ...[
                                            LiveActiveResearchCard(
                                              research: research,
                                              isUpgrading: _isUpgrading,
                                              onCollect: _onCollect,
                                              onFinishWithGold:
                                                  _onFinishWithGold,
                                            ),
                                            if (research != researches.last)
                                              SizedBox(height: 10.h),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                              child: _buildSearchBar(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
                              child: _buildUnitFilters(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
                              child: _buildScopeFilters(),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 24.h),
                            sliver: _buildProductList(
                              context,
                              _filter(
                                products,
                                playerLevel: player?.level ?? 1,
                                playerCash: (player?.cash ?? 0).toDouble(),
                                activeResearchCount:
                                    researchesAsync.value?.length ?? 0,
                                maxConcurrentResearches:
                                    center.maxConcurrentResearches,
                              ),
                              player?.level ?? 1,
                              (player?.cash ?? 0).toDouble(),
                              researchesAsync.value?.length ?? 0,
                              center.maxConcurrentResearches,
                              products,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBanner(ArgeCenterModel center, [int activeResearches = 0]) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF131B2E),
            Color(0xFF1A233A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.domain_rounded,
            const Color(0xFF38BDF8),
            center.name,
            'Seviye ${center.level}',
            AppColors.textPrimary,
          ),
          _buildDivider(),
          _buildStatItem(
            Icons.science_rounded,
            AppColors.gold,
            'Araştırma Slotu',
            '$activeResearches/${center.maxConcurrentResearches} Aktif',
            activeResearches >= center.maxConcurrentResearches
                ? Colors.orangeAccent
                : AppColors.green,
          ),
          _buildDivider(),
          _buildStatItem(
            Icons.bolt_rounded,
            const Color(0xFF10B981),
            'Süre İndirimi',
            '%${center.durationReductionPct.toStringAsFixed(0)} Hız',
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterActions(
    ArgeCenterModel center,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    color: const Color(0xFF38BDF8),
                    size: 20.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Kapasite: ${_slotPreviewText(center, activeUpgrade)}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          FilledButton.icon(
            onPressed: (_isCenterSubmitting || activeUpgrade != null)
                ? null
                : () => _showCenterUpgradeSheet(center),
            icon: Icon(Icons.arrow_circle_up_rounded, size: 18.sp),
            label: Text(
              activeUpgrade != null ? 'Yükseliyor...' : 'Merkezi Yükselt',
              style: AppTextStyles.body.standardCopyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.cardBgLight,
              disabledForegroundColor: AppColors.textMuted,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }

  String _slotPreviewText(
    ArgeCenterModel center,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    if (activeUpgrade == null) {
      return '${center.maxConcurrentResearches} Eşzamanlı Slot';
    }

    final nextSlots =
        (activeUpgrade.params['next_concurrent_researches'] as num?)?.toInt() ??
        center.maxConcurrentResearches;
    return '${center.maxConcurrentResearches} ➔ $nextSlots Slot';
  }

  Widget _buildDivider() {
    return Container(
      width: 1.w,
      height: 38.h,
      color: const Color(0xFF334155),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color valueColor,
  ) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.w),
              ),
              child: Icon(icon, color: iconColor, size: 16.sp),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.standardCopyWith(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: AppTextStyles.body.standardCopyWith(
                      color: valueColor,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.body.standardCopyWith(
          color: AppColors.textPrimary,
          fontSize: 13.5.sp,
        ),
        decoration: InputDecoration(
          hintText: 'Ürün veya hammadde ara...',
          hintStyle: AppTextStyles.body.standardCopyWith(
            color: const Color(0xFF64748B),
            fontSize: 13.sp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: const Color(0xFF64748B),
            size: 20.sp,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 16.sp, color: const Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 10.h,
          ),
        ),
      ),
    );
  }

  Widget _buildUnitFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _unitFilters.map((filter) {
          final isSelected = _selectedUnit == filter.$1;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedUnit = filter.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : const Color(0xFF334155),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: isSelected
                        ? AppColors.goldLight
                        : const Color(0xFF94A3B8),
                    fontSize: 11.5.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static const _scopeFilters = [
    ('TUMU', 'Tüm Ürünler'),
    ('URETTIKLERIM', 'Sadece Ürettiklerim'),
    ('ARASTIRILABILIR', 'Araştırılabilirler'),
  ];

  Widget _buildScopeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _scopeFilters.map((filter) {
          final isSelected = _selectedScope == filter.$1;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedScope = filter.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF334155),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF94A3B8),
                    fontSize: 11.5.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    List<ArgeProductModel> products,
    int playerLevel,
    double playerCash,
    int activeResearchCount,
    int maxConcurrentResearches,
    List<ArgeProductModel> allProducts,
  ) {
    if (products.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: _buildProductListItem(
            products[index],
            playerLevel: playerLevel,
            playerCash: playerCash,
            activeResearchCount: activeResearchCount,
            maxConcurrentResearches: maxConcurrentResearches,
            allProducts: allProducts,
          ),
        ),
        childCount: products.length,
      ),
    );
  }

  Widget _buildProductListItem(
    ArgeProductModel product, {
    required int playerLevel,
    required double playerCash,
    required int activeResearchCount,
    required int maxConcurrentResearches,
    required List<ArgeProductModel> allProducts,
  }) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final meetsRawMaterials = product.meetsRawMaterialQualityRequirements(allProducts);
    final hasFreeResearchSlot = activeResearchCount < maxConcurrentResearches;
    final canUpgrade =
        product.canUpgrade(
          playerLevel: playerLevel,
          playerCash: playerCash,
          allProducts: allProducts,
        ) &&
        hasFreeResearchSlot;

    final targetQualityColor = _getQualityColor(product.targetQuality);

    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: product.isMaxQuality
              ? AppColors.green.withValues(alpha: 0.4)
              : canUpgrade
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                  : const Color(0xFF334155),
          width: canUpgrade ? 1.3 : 1.0,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131B2E),
            canUpgrade ? const Color(0xFF162444) : const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              shape: BoxShape.circle,
              border: Border.all(
                color: targetQualityColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: CachedAssetImage(
              fileName: product.urunIconu,
              fit: BoxFit.contain,
              errorWidget: Icon(
                Icons.science_rounded,
                color: AppColors.gold,
                size: 24.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.urunAdi,
                        style: AppTextStyles.h2.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.isProduced) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'ÜRETİLİYOR',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.green,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    // Gemstone Star representation
                    Row(
                      children: List.generate(ArgeProductModel.maxQualityLevel, (index) {
                        final starQuality = index + 1;
                        final filled = index < product.currentQualityLevel;
                        final starColor = filled ? _getQualityColor(starQuality) : const Color(0xFF334155);
                        return Padding(
                          padding: EdgeInsets.only(right: 2.w),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: starColor,
                            size: 14.sp,
                          ),
                        );
                      }),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: targetQualityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: targetQualityColor.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        product.isMaxQuality ? 'MAKS (Q5)' : 'Q${product.currentQualityLevel} ➔ Q${product.targetQuality}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: product.isMaxQuality ? AppColors.green : targetQualityColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!product.isMaxQuality && (!hasLevel || !meetsRawMaterials)) ...[
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      if (!hasLevel) ...[
                        Icon(Icons.lock_rounded, size: 12.sp, color: Colors.redAccent),
                        SizedBox(width: 3.w),
                        Text(
                          'Lv.${product.requiredPlayerLevel} Gerekli',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: Colors.redAccent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6.w),
                      ],
                      if (!meetsRawMaterials) ...[
                        Icon(Icons.inventory_2_outlined, size: 12.sp, color: Colors.orangeAccent),
                        SizedBox(width: 3.w),
                        Text(
                          'Hammadde Q${product.targetQuality - 1} Gerekli',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: Colors.orangeAccent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!product.isMaxQuality) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniReqBadge(
                      Icons.account_balance_wallet_outlined,
                      _formatMoney(product.upgradeCost),
                      hasCash ? AppColors.gold : Colors.redAccent,
                    ),
                    SizedBox(width: 4.w),
                    _buildMiniReqBadge(
                      Icons.timer_outlined,
                      '${product.upgradeDurationHours}s',
                      const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              SizedBox(
                width: 84.w,
                height: 30.h,
                child: FilledButton(
                  onPressed: product.isMaxQuality
                      ? null
                      : () => _showUpgradeSheet(
                          product,
                          playerLevel: playerLevel,
                          playerCash: playerCash,
                          hasAvailableResearchSlot: hasFreeResearchSlot,
                          allProducts: allProducts,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: canUpgrade
                        ? AppColors.gold
                        : const Color(0xFF1E293B),
                    foregroundColor: canUpgrade
                        ? AppColors.textOnAccent
                        : const Color(0xFF64748B),
                    disabledBackgroundColor: const Color(0xFF1E293B),
                    disabledForegroundColor: const Color(0xFF64748B),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    product.isMaxQuality ? 'MAKS' : (canUpgrade ? 'Geliştir' : 'İncele'),
                    style: AppTextStyles.caption.standardCopyWith(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _getQualityColor(int quality) {
    return switch (quality) {
      2 => const Color(0xFF10B981), // Emerald
      3 => const Color(0xFF38BDF8), // Sapphire
      4 => const Color(0xFFA855F7), // Amethyst
      5 => const Color(0xFFF59E0B), // Radiant Gold
      _ => const Color(0xFF94A3B8), // Slate
    };
  }

  Widget _buildMiniReqBadge(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 3.w),
          Text(
            text,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeSheet(
    ArgeProductModel product, {
    required int playerLevel,
    required double playerCash,
    required bool hasAvailableResearchSlot,
    required List<ArgeProductModel> allProducts,
  }) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final meetsRawMaterials = product.meetsRawMaterialQualityRequirements(allProducts);
    final canStart =
        hasLevel &&
        hasCash &&
        meetsRawMaterials &&
        hasAvailableResearchSlot &&
        !product.isMaxQuality;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _UpgradeBottomSheet(
        product: product,
        playerLevel: playerLevel,
        playerCash: playerCash,
        canStart: canStart,
        hasActiveResearch: !hasAvailableResearchSlot,
        allProducts: allProducts,
        onStart: () async {
          Navigator.of(context).pop();
          await _onStartResearch(product.id);
        },
      ),
    );
  }

  Future<void> _onStartResearch(String productId) async {
    setState(() => _isUpgrading = true);
    final result = await ref.read(argeActionProvider).startResearch(productId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(ref.read(playerArgeCenterProvider).value?.id);
      AppSnackbar.show(
        context,
        title: 'Araştırma Başladı',
        message: '${result['product_name']} için geliştirme başlatıldı.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _onCollect(String researchId) async {
    setState(() => _isUpgrading = true);
    final result = await ref
        .read(argeActionProvider)
        .completeResearch(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(ref.read(playerArgeCenterProvider).value?.id);
      AppSnackbar.show(
        context,
        title: 'Geliştirme Tamamlandı!',
        message:
            '${result['product_name']} kalite ${result['new_quality_level']} seviyesine ulasti.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _onFinishWithGold(String researchId, int goldCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Anında Tamamla',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.goldLight,
            fontSize: AppTypography.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$goldCost yıldız kullanarak araştırmayı anında tamamlamak istiyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Tamamla',
              style: AppTextStyles.body.standardCopyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isUpgrading = true);
    final result = await ref
        .read(argeActionProvider)
        .finishWithGold(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(ref.read(playerArgeCenterProvider).value?.id);
      AppSnackbar.show(
        context,
        title: 'Tamamlandı!',
        message:
            '${result['product_name']} geliştirmesi tamamlandı. ${result['gold_spent']} yıldız harcandı.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  int _calculateUpgradeStarCost(DateTime finishAt) {
    final now = DateTime.now();
    final remaining = finishAt.difference(now);
    if (remaining.inMinutes <= 0) return 0;
    return ((remaining.inMinutes + 29) ~/ 30).clamp(1, 999999);
  }

  String _formatCountdown(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showCenterUpgradeSheet(ArgeCenterModel center) {
    final nextLevel = center.level + 1;
    final nextSlots = nextLevel >= 6
        ? 4
        : nextLevel >= 4
        ? 3
        : nextLevel >= 2
        ? 2
        : 1;
    final nextDurationReduction = switch (nextLevel) {
      1 => 0.0,
      2 => 5.0,
      3 => 10.0,
      4 => 15.0,
      5 => 20.0,
      _ => 25.0,
    };
    final durationMinutes = 60 * nextLevel;
    final upgradeCost = 25000.0 * nextLevel;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(color: AppColors.borderGold),
        ),
        padding: EdgeInsets.fromLTRB(5.w, 18.h, 5.w, 24.h),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AR-GE Merkezini Yukselt',
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.goldLight,
                  fontSize: AppTypography.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 14.h),
              _buildSetupRow('Seviye', '${center.level} -> $nextLevel'),
              _buildSetupRow(
                'Araştırma Slotu',
                '${center.maxConcurrentResearches} -> $nextSlots',
              ),
              _buildSetupRow(
                'Süre Bonusu',
                '%${center.durationReductionPct.toStringAsFixed(0)} -> %${nextDurationReduction.toStringAsFixed(0)}',
              ),
              _buildSetupRow('Yükseltme Süresi', '$durationMinutes dakika'),
              _buildSetupRow('Maliyet', _formatMoney(upgradeCost)),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _startCenterUpgrade(center.id);
                  },
                  icon: Icon(
                    AppIcons.upgradeRounded,
                    size: AppIconSizes.regular,
                  ),
                  label: Text(
                    'Yukseltmeyi Baslat',
                    style: AppTextStyles.body.standardCopyWith(
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCenterUpgrade(String centerId) async {
    setState(() => _isCenterSubmitting = true);
    final result = await ref
        .read(argeActionProvider)
        .startCenterUpgrade(centerId);
    setState(() => _isCenterSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(centerId);
      AppSnackbar.show(
        context,
        title: 'Yukseltme Basladi',
        message: 'AR-GE merkezi icin yeni seviye calismasi baslatildi.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _finishCenterUpgradeWithGold(
    BuildingUpgradeModel upgrade,
  ) async {
    final result = await ref
        .read(argeActionProvider)
        .finishCenterUpgradeWithGold(upgrade.id);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(upgrade.entityId);
      AppSnackbar.show(
        context,
        title: 'Yükseltme Tamamlandı',
        message:
            'AR-GE merkezi anında tamamlandı. ${result['gold_spent']} yıldız harcandı.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _reduceCenterUpgradeTimeWithAd(
    BuildingUpgradeModel upgrade,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'upgrade_time_reduce',
      resourceId: upgrade.id,
      onApplyReduction: () => ref
          .read(argeActionProvider)
          .reduceCenterUpgradeTimeWithAd(upgrade.id),
      successMessage: 'Merkez yükseltme süresi 10 dakika kısaltıldı.',
    );

    if (success) {
      _refreshCenterEcosystem(upgrade.entityId);
    }
  }

  Widget _buildSetupState(dynamic player) {
    final playerCash = double.tryParse(player?.cash?.toString() ?? '0') ?? 0;
    const setupCost = 25000.0;
    const setupDurationMinutes = 60;
    final hasCash = playerCash >= setupCost;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderGold),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.cardBg,
                  AppColors.cardBgLight.withValues(alpha: 0.45),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58.w,
                  height: 58.w,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    AppIcons.scienceOutlined,
                    color: AppColors.blue,
                    size: AppIconSizes.xLarge,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AR-GE Merkezi Kur',
                        style: AppTextStyles.h2.standardCopyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Kalite geliştirmelerini başlatmak için önce araştırma merkezinizi faaliyete geçirin.',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merkez Bilgileri',
                  style: AppTextStyles.h2.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.titleLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildSetupRow('Kurulum Maliyeti', _formatMoney(setupCost)),
                _buildSetupRow('İnşaat Süresi', '$setupDurationMinutes dakika'),
                _buildSetupRow('Başlangıç Slotu', '1 Araştırma'),
                _buildSetupRow('Süre Bonusu', '%0'),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: hasCash
                  ? AppColors.green.withValues(alpha: 0.08)
                  : AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: hasCash
                    ? AppColors.green.withValues(alpha: 0.3)
                    : AppColors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasCash ? AppIcons.checkCircleOutline : AppIcons.errorOutline,
                  color: hasCash ? AppColors.green : AppColors.red,
                  size: AppIconSizes.regular,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    hasCash
                        ? 'Kurulum icin yeterli bakiyeniz var.'
                        : 'Yetersiz bakiye. Mevcut: ${_formatMoney(playerCash)}',
                    style: AppTextStyles.body.standardCopyWith(
                      color: hasCash ? AppColors.green : AppColors.red,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_isCenterSubmitting || !hasCash)
                  ? null
                  : _onStartCenterConstruction,
              icon: _isCenterSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const AppLoadingIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      AppIcons.constructionOutlined,
                      size: AppIconSizes.regular,
                    ),
              label: Text(
                _isCenterSubmitting ? 'Kuruluyor...' : 'AR-GE MERKEZINI KUR',
                style: AppTextStyles.body.standardCopyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.bodyLarge,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor: AppColors.cardBgLight,
                disabledForegroundColor: AppColors.textMuted,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstructionState(Map<String, dynamic> construction) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final params = construction['params'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(
            construction['params'] as Map<String, dynamic>,
          )
        : construction['params'] is Map
        ? Map<String, dynamic>.from(construction['params'] as Map)
        : <String, dynamic>{};
    final finishAt = DateTime.tryParse(
      construction['finish_at']?.toString() ?? '',
    );
    final remaining = finishAt == null
        ? Duration.zero
        : finishAt.difference(now);
    final isDone =
        !remaining.isNegative && remaining.inSeconds == 0 ||
        (finishAt != null && !finishAt.isAfter(now));
    final remainingMinutes = remaining.isNegative
        ? 0
        : (remaining.inSeconds / 60).ceil();
    final goldCost = remainingMinutes <= 0
        ? 0
        : ((remainingMinutes + 29) ~/ 30);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderGold),
            ),
            child: Row(
              children: [
                Container(
                  width: 58.w,
                  height: 58.w,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    AppIcons.construction,
                    color: AppColors.gold,
                    size: AppIconSizes.xLarge,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (params['name'] ?? 'AR-GE Merkezi').toString(),
                        style: AppTextStyles.h2.standardCopyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Merkez kurulumu devam ediyor. İnşaat tamamlanınca araştırmalar aktif olacak.',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSetupRow(
                  'Kalan Süre',
                  isDone ? 'Hazir' : _formatRemaining(remaining),
                ),
                _buildSetupRow(
                  'Bitis Zamani',
                  finishAt == null ? '-' : _formatDateTime(finishAt),
                ),
                _buildSetupRow(
                  'Kurulum Maliyeti',
                  _formatMoney(
                    double.tryParse(params['cost']?.toString() ?? '0') ?? 0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isDone
                  ? () => _onCompleteCenterConstruction(
                      construction['id'].toString(),
                    )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                disabledBackgroundColor: AppColors.cardBgLight,
                foregroundColor: AppColors.textPrimary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                isDone ? 'KURULUMU TAMAMLA' : 'KURULUM DEVAM EDİYOR',
                style: AppTextStyles.body.standardCopyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.bodyLarge,
                ),
              ),
            ),
          ),
          if (!isDone) ...[
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: goldCost <= 0
                    ? null
                    : () => _onFinishCenterConstructionWithGold(
                        construction['id'].toString(),
                        goldCost,
                      ),
                icon: Icon(
                  AppIcons.bolt,
                  size: AppIconSizes.compact,
                  color: AppColors.gold,
                ),
                label: Text(
                  '$goldCost yildiz ile hemen bitir',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetupRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStartCenterConstruction() async {
    setState(() => _isCenterSubmitting = true);
    final result = await ref.read(argeActionProvider).startCenterConstruction();
    setState(() => _isCenterSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem();
      AppSnackbar.show(
        context,
        title: 'Kurulum Basladi',
        message: 'AR-GE merkezinizin kurulumu baslatildi.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _onCompleteCenterConstruction(String constructionId) async {
    setState(() => _isCenterSubmitting = true);
    final result = await ref
        .read(argeActionProvider)
        .completeConstruction(constructionId, syncProviders: false);
    setState(() => _isCenterSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem();
      AppSnackbar.show(
        context,
        title: 'Kurulum Tamamlandı',
        message: 'AR-GE merkeziniz kullanima acildi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _onFinishCenterConstructionWithGold(
    String constructionId,
    int goldCost,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Kurulumu Bitir',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.goldLight,
            fontSize: AppTypography.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$goldCost yildiz kullanarak AR-GE merkezini hemen kullanima acmak istiyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Bitir',
              style: AppTextStyles.body.standardCopyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCenterSubmitting = true);
    final result = await ref
        .read(argeActionProvider)
        .finishConstructionWithGold(constructionId);
    setState(() => _isCenterSubmitting = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem();
      AppSnackbar.show(
        context,
        title: 'Kurulum Tamamlandı',
        message:
            'AR-GE merkeziniz acildi. ${result['gold_spent'] ?? goldCost} yildiz harcandi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Bilinmeyen hata.',
        type: SnackbarType.error,
      );
    }
  }

  Widget _buildEmptyState() {
    final hasSearchFilter =
        _searchQuery.isNotEmpty ||
        _selectedUnit != 'TUMU' ||
        _selectedScope != 'TUMU';
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          children: [
            SizedBox(height: 40.h),
            Icon(
              hasSearchFilter ? AppIcons.searchOff : AppIcons.science,
              color: AppColors.textMuted,
              size: AppIconSizes.emptyState,
            ),
            SizedBox(height: 16.h),
            Text(
              hasSearchFilter
                  ? 'Kriterlere uygun ürün bulunamadı.'
                  : 'Henüz kalitesi artırılmış bir ürününüz yok.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.title,
              ),
            ),
            if (!hasSearchFilter) ...[
              SizedBox(height: 12.h),
              Text(
                'Yeni bir araştırma başlatmak için sağ alttaki "Araştırma Yap" butonunu kullanabilirsiniz.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: AppTypography.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.errorOutline,
            color: AppColors.red,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 12.h),
          Text(
            error.toString(),
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.body,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
            ),
            child: Text(
              'Tekrar Dene',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }

  String _formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime value) {
    final safe = value.toLocal();
    final day = safe.day.toString().padLeft(2, '0');
    final month = safe.month.toString().padLeft(2, '0');
    final hour = safe.hour.toString().padLeft(2, '0');
    final minute = safe.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

class _ActiveArgeUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final Future<void> Function()? onReduceTimeWithAd;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(DateTime finishAt) formatCountdown;

  const _ActiveArgeUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    this.onReduceTimeWithAd,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final total = upgrade.finishAt.difference(upgrade.startedAt).inSeconds;
    final elapsed = now.difference(upgrade.startedAt).inSeconds;
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final starCost = calculateStarCost(upgrade.finishAt);
    final nextSlots =
        (upgrade.params['next_concurrent_researches'] as num?)?.toInt() ?? 1;
    final prevSlots =
        (upgrade.params['previous_concurrent_researches'] as num?)?.toInt() ??
        1;
    final nextReduction =
        (upgrade.params['next_duration_reduction_pct'] as num?)?.toDouble() ??
        0;
    final prevReduction =
        (upgrade.params['previous_duration_reduction_pct'] as num?)
            ?.toDouble() ??
        0;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.upgradeRounded,
                  color: AppColors.gold,
                  size: AppIconSizes.regular,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merkez Yukseliyor',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${upgrade.name ?? 'AR-GE Merkezi'}  Lv.${upgrade.currentLevel} -> Lv.${upgrade.targetLevel}',
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCountdown(upgrade.finishAt),
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          AppProgressBar(
            value: progress,
            minHeight: 8.h,
            backgroundColor: AppFx.panelWash(0.3),
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(999.r),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _ArgeUpgradeMeta(
                  label: 'Araştırma Slotu',
                  value: '$prevSlots -> $nextSlots',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _ArgeUpgradeMeta(
                  label: 'Süre Bonusu',
                  value:
                      '%${prevReduction.toStringAsFixed(0)} -> %${nextReduction.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          if (starCost > 0) ...[
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onFinishWithGold,
                icon: Icon(AppIcons.flashOnRounded, size: AppIconSizes.compact),
                label: Text(
                  '$starCost yildizla bitir',
                  style: AppTextStyles.body.standardCopyWith(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
          if (upgrade.finishAt.isAfter(now) && onReduceTimeWithAd != null) ...[
            SizedBox(height: 10.h),
            RewardedTimeReduceButton(
              onPressed: () => onReduceTimeWithAd!.call(),
              caption:
                  'Bir reklam ödülü al ve merkez yükseltme süresini 10 dakika kısalt.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ArgeUpgradeMeta extends StatelessWidget {
  final String label;
  final String value;

  const _ArgeUpgradeMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.label,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBottomSheet extends StatelessWidget {
  final ArgeProductModel product;
  final int playerLevel;
  final double playerCash;
  final bool canStart;
  final bool hasActiveResearch;
  final VoidCallback onStart;
  final List<ArgeProductModel> allProducts;

  const _UpgradeBottomSheet({
    required this.product,
    required this.playerLevel,
    required this.playerCash,
    required this.canStart,
    required this.hasActiveResearch,
    required this.onStart,
    required this.allProducts,
  });

  List<Widget> _buildRawMaterialRequirementsList(BuildContext context) {
    final List<Widget> widgets = [];
    final requiredQuality = product.targetQuality - 1;

    void addRMRow(String? rmId) {
      if (rmId == null || rmId.isEmpty) return;
      final rm = allProducts.firstWhere(
        (p) => p.id == rmId,
        orElse: () => const ArgeProductModel(
          id: '',
          urunAdi: '',
          urunIconu: '',
          bazSatisFiyati: 0,
          uretimBirimi: '',
          currentQualityLevel: 1,
          isProduced: false,
        ),
      );
      if (rm.id.isNotEmpty) {
        final ok = rm.currentQualityLevel >= requiredQuality;

        widgets.add(
          Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: ok
                  ? const Color(0xFF0F2D24)
                  : const Color(0xFF2D1217),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: ok
                    ? AppColors.green.withValues(alpha: 0.4)
                    : Colors.redAccent.withValues(alpha: 0.4),
                width: 1.w,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1120),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (ok ? AppColors.green : Colors.redAccent).withValues(alpha: 0.4),
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: rm.urunIconu,
                    fit: BoxFit.contain,
                    errorWidget: Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.gold,
                      size: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rm.urunAdi,
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        ok ? 'Kalite Koşulu Sağlandı' : 'Önce bu hammaddeyi geliştirin',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: ok ? const Color(0xFF94A3B8) : Colors.orangeAccent,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: (ok ? AppColors.green : Colors.redAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Q${rm.currentQualityLevel} / Gerekli: Q$requiredQuality',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: ok ? AppColors.green : Colors.redAccent,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    addRMRow(product.hammadde1Id);
    addRMRow(product.hammadde2Id);
    addRMRow(product.hammadde3Id);

    return widgets;
  }

  static Color _getQualityColor(int quality) {
    return switch (quality) {
      2 => const Color(0xFF10B981),
      3 => const Color(0xFF38BDF8),
      4 => const Color(0xFFA855F7),
      5 => const Color(0xFFF59E0B),
      _ => const Color(0xFF94A3B8),
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final meetsRawMaterials = product.meetsRawMaterialQualityRequirements(allProducts);
    final targetQualityColor = _getQualityColor(product.targetQuality);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1120),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: targetQualityColor.withValues(alpha: 0.5),
                    width: 2.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: targetQualityColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CachedAssetImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                  errorWidget: Icon(
                    Icons.science_rounded,
                    color: AppColors.gold,
                    size: 28.sp,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.urunAdi,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: List.generate(
                        ArgeProductModel.maxQualityLevel,
                        (index) {
                          final starQuality = index + 1;
                          final filled = index < product.currentQualityLevel;
                          final starColor = filled ? _getQualityColor(starQuality) : const Color(0xFF334155);
                          return Padding(
                            padding: EdgeInsets.only(right: 2.w),
                            child: Icon(
                              filled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: starColor,
                              size: 16.sp,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Text(
                          'Mevcut: Q${product.currentQualityLevel}',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5.w),
                          child: Icon(Icons.arrow_forward_rounded, color: targetQualityColor, size: 13.sp),
                        ),
                        Text(
                          'Hedef: Q${product.targetQuality}',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: targetQualityColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Divider(color: const Color(0xFF334155), height: 1),
          SizedBox(height: 14.h),
          _buildRequirementRow(
            icon: Icons.military_tech_rounded,
            label: 'Gerekli Oyuncu Seviyesi',
            value: 'Seviye ${product.requiredPlayerLevel}',
            ok: hasLevel,
            currentValue: 'Mevcut: Lv.$playerLevel',
          ),
          SizedBox(height: 10.h),
          _buildRequirementRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Araştırma Bütçesi',
            value: _formatMoney(product.upgradeCost),
            ok: hasCash,
            currentValue: 'Mevcut: ${_formatMoney(playerCash)}',
          ),
          SizedBox(height: 10.h),
          _buildRequirementRow(
            icon: Icons.timer_outlined,
            label: 'Araştırma Süresi',
            value: '${product.upgradeDurationHours} Saat',
            ok: true,
            currentValue: 'Her 30 dk = 1 ★',
          ),
          if (product.hammadde1Id != null && product.hammadde1Id!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Divider(color: const Color(0xFF334155), height: 1),
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: const Color(0xFF38BDF8), size: 16.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'Hammadde Kalite Şartları (En Az Q${product.targetQuality - 1})',
                    style: AppTextStyles.body.standardCopyWith(
                      color: const Color(0xFF38BDF8),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            ..._buildRawMaterialRequirementsList(context),
          ],
          SizedBox(height: 14.h),
          Divider(color: const Color(0xFF334155), height: 1),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFF38BDF8),
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Kalite yükseltildiğinde fabrikalarınız bu ürünü daha yüksek satış değeri ve pazar talebiyle üretmeye başlayacaktır.',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveResearch) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Tüm araştırma slotlarınız dolu. Önce aktif araştırmanın bitmesini bekleyin.',
                      style: AppTextStyles.body.standardCopyWith(
                        color: Colors.redAccent,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!meetsRawMaterials) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Gerekli hammaddeler henüz yeterli kalite seviyesine (Q${product.targetQuality - 1}) ulaşmamış.',
                      style: AppTextStyles.body.standardCopyWith(
                        color: Colors.redAccent,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: canStart ? onStart : null,
              icon: Icon(Icons.science_rounded, size: 20.sp),
              label: Text(
                canStart ? 'ARAŞTIRMAYI BAŞLAT' : 'KOŞULLAR SAĞLANMADI',
                style: AppTextStyles.body.standardCopyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart
                    ? AppColors.gold
                    : const Color(0xFF1E293B),
                foregroundColor: canStart
                    ? AppColors.textOnAccent
                    : const Color(0xFF64748B),
                disabledBackgroundColor: const Color(0xFF1E293B),
                disabledForegroundColor: const Color(0xFF64748B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: canStart ? 4 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required IconData icon,
    required String label,
    required String value,
    required bool ok,
    required String currentValue,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: (ok ? AppColors.green : Colors.redAccent).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: (ok ? AppColors.green : Colors.redAccent).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              color: ok ? AppColors.green : Colors.redAccent,
              size: 14.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: (ok ? AppColors.green : Colors.redAccent).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              currentValue,
              style: AppTextStyles.caption.standardCopyWith(
                color: ok ? AppColors.green : Colors.redAccent,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }
}

class _NewResearchProductSelectionSheet extends StatefulWidget {
  final List<ArgeProductModel> allProducts;
  final int playerLevel;
  final double playerCash;
  final int activeResearchCount;
  final int maxConcurrentResearches;
  final ValueChanged<ArgeProductModel> onSelect;

  const _NewResearchProductSelectionSheet({
    required this.allProducts,
    required this.playerLevel,
    required this.playerCash,
    required this.activeResearchCount,
    required this.maxConcurrentResearches,
    required this.onSelect,
  });

  @override
  State<_NewResearchProductSelectionSheet> createState() =>
      __NewResearchProductSelectionSheetState();
}

class __NewResearchProductSelectionSheetState
    extends State<_NewResearchProductSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allProducts.where((product) {
      if (product.isMaxQuality) return false;
      if (_query.isEmpty) return true;
      return product.urunAdi.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      if (a.isProduced != b.isProduced) {
        return a.isProduced ? -1 : 1;
      }
      return a.urunAdi.compareTo(b.urunAdi);
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(
            color: AppColors.borderGold.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Yeni Araştırma Başlat',
                  style: AppTextStyles.h1.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.headline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(AppIcons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim()),
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ürün ara...',
                hintStyle: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                ),
                prefixIcon: Icon(AppIcons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppFx.panelWash(0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppFx.softOverlay(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.gold),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          Divider(color: AppFx.softOverlay(0.1), height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.searchOff,
                          color: AppColors.textMuted,
                          size: 48.w,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Aradığınız kriterde ürün bulunamadı.',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return InkWell(
                        onTap: () => widget.onSelect(product),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppFx.softOverlay(0.02),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: CachedAssetImage(
                                  fileName: product.urunIconu,
                                  fit: BoxFit.contain,
                                  errorWidget: Icon(
                                    AppIcons.science,
                                    color: AppColors.gold,
                                    size: AppIconSizes.medium,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            product.urunAdi,
                                            style: AppTextStyles.title
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize: AppTypography.body,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (product.isProduced) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4.w,
                                              vertical: 1.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.green.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              'Üretiyorsunuz',
                                              style: TextStyle(
                                                color: AppColors.green,
                                                fontSize: 8.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: List.generate(5, (starIdx) {
                                        final filled =
                                            starIdx <
                                            product.currentQualityLevel;
                                        return Icon(
                                          filled
                                              ? AppIcons.star
                                              : AppIcons.starBorder,
                                          color: filled
                                              ? AppColors.gold
                                              : AppColors.textMuted,
                                          size: 10.w,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                AppIcons.chevronRightRounded,
                                color: AppColors.textMuted,
                                size: AppIconSizes.compact,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
