import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
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
  bool _isUpgrading = false;
  bool _isCenterSubmitting = false;

  static const _unitFilters = [
    ('TUMU', 'Tumu'),
    ('FABRIKA', 'Fabrika'),
    ('TARLA', 'Tarla'),
    ('CIFTLIK', 'Ciftlik'),
    ('MADEN', 'Maden'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
    ref.invalidate(playerProvider);
    if (centerId != null && centerId.isNotEmpty) {
      ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
    }
  }

  List<ArgeProductModel> _filter(List<ArgeProductModel> products) {
    return products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.urunAdi.toLowerCase().contains(_searchQuery);
      final matchesUnit =
          _selectedUnit == 'TUMU' || product.uretimBirimi == _selectedUnit;
      return matchesSearch && matchesUnit;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ArgeResearchModel?>>(
      activeArgeResearchProvider,
      (previous, next) {
        final research = next.value;
        if (research != null && research.isDone) {
          ref.read(argeActionProvider).completeResearch(research.id);
        }
      },
    );

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
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'AR-GE Merkezi'),
            Expanded(
              child: centerAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildError(error),
                data: (center) {
                  if (center == null) {
                    return constructionAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (error, _) => _buildError(error),
                      data: (construction) {
                        if (construction != null) {
                          return _buildConstructionState(construction);
                        }

                        return playerAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(color: AppColors.gold),
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
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
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
                              child: _buildStatsBanner(center),
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
                                      padding:
                                          EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                                      child: _ActiveArgeUpgradeCard(
                                        upgrade: upgrade,
                                        onFinishWithGold: () =>
                                            _finishCenterUpgradeWithGold(upgrade),
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
                              error: (_, _) => const SizedBox.shrink(),
                              data: (researches) => researches.isEmpty
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                                      child: Column(
                                        children: [
                                          for (final research in researches) ...[
                                            LiveActiveResearchCard(
                                              research: research,
                                              isUpgrading: _isUpgrading,
                                              onCollect: _onCollect,
                                              onFinishWithGold: _onFinishWithGold,
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
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 24.h),
                            sliver: _buildProductGrid(
                              context,
                              _filter(products),
                              player?.level ?? 1,
                              (player?.cash ?? 0).toDouble(),
                              researchesAsync.value?.length ?? 0,
                              center.maxConcurrentResearches,
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

  Widget _buildStatsBanner(ArgeCenterModel center) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.apartment_rounded,
            AppColors.blue,
            center.name,
            'Lv.${center.level}',
            Colors.white,
          ),
          _buildDivider(),
          _buildStatItem(
            Icons.star,
            AppColors.gold,
            'Arastirma Slotu',
            '${center.maxConcurrentResearches} eszamanli',
            AppColors.goldLight,
          ),
          _buildDivider(),
          _buildStatItem(
            Icons.bolt_rounded,
            AppColors.green,
            'Sure Bonusu',
            '%${center.durationReductionPct.toStringAsFixed(0)}',
            AppColors.green,
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
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppColors.blue, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Arastirma slotu: ${_slotPreviewText(center, activeUpgrade)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
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
            icon: Icon(Icons.upgrade_rounded, size: 16.sp),
            label: Text(
              activeUpgrade != null ? 'Yukseliyor' : 'Yukselt',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.cardBgLight,
              disabledForegroundColor: AppColors.textMuted,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
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
      return center.maxConcurrentResearches.toString();
    }

    final nextSlots =
        (activeUpgrade.params['next_concurrent_researches'] as num?)?.toInt() ??
            center.maxConcurrentResearches;
    return '${center.maxConcurrentResearches} -> $nextSlots';
  }

  Widget _buildDivider() {
    return Container(
      width: 1.w,
      height: 36.h,
      color: AppColors.border.withValues(alpha: 0.5),
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
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 15.sp),
            ),
            SizedBox(width: 7.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 12.sp,
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
      height: 42.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Urun ara...',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 18.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                      ? AppColors.gold.withValues(alpha: 0.14)
                      : AppColors.cardBg.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.goldLight : AppColors.textSecondary,
                    fontSize: 11.sp,
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

  Widget _buildProductGrid(
    BuildContext context,
    List<ArgeProductModel> products,
    int playerLevel,
    double playerCash,
    int activeResearchCount,
    int maxConcurrentResearches,
  ) {
    if (products.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardAspectRatio = screenWidth < 380
        ? 0.52
        : screenWidth < 430
            ? 0.56
            : 0.60;

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildProductCard(
          products[index],
          playerLevel: playerLevel,
          playerCash: playerCash,
          activeResearchCount: activeResearchCount,
          maxConcurrentResearches: maxConcurrentResearches,
        ),
        childCount: products.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: cardAspectRatio,
      ),
    );
  }

  Widget _buildProductCard(
    ArgeProductModel product, {
    required int playerLevel,
    required double playerCash,
    required int activeResearchCount,
    required int maxConcurrentResearches,
  }) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final hasFreeResearchSlot = activeResearchCount < maxConcurrentResearches;
    final canUpgrade = product.canUpgrade(
          playerLevel: playerLevel,
          playerCash: playerCash,
        ) &&
        hasFreeResearchSlot;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: product.isMaxQuality
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.5),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 64.w,
              height: 64.w,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: CachedAssetImage(
                fileName: product.urunIconu,
                fit: BoxFit.contain,
                errorWidget: Icon(
                  Icons.science,
                  color: AppColors.gold,
                  size: 28.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            product.urunAdi,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: List.generate(ArgeProductModel.maxQualityLevel, (index) {
              final filled = index < product.currentQualityLevel;
              return Padding(
                padding: EdgeInsets.only(right: 2.w),
                child: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? AppColors.gold : AppColors.textMuted,
                  size: 14.sp,
                ),
              );
            }),
          ),
          SizedBox(height: 4.h),
          Text(
            'Kalite ${product.currentQualityLevel} -> ${product.targetQuality}',
            style: TextStyle(color: AppColors.blue, fontSize: 10.sp),
          ),
          SizedBox(height: 6.h),
          _buildRequirementChip(
            Icons.account_balance_wallet_outlined,
            _formatMoney(product.upgradeCost),
            hasCash ? AppColors.gold : AppColors.red,
          ),
          SizedBox(height: 5.h),
          _buildRequirementChip(
            Icons.workspace_premium_outlined,
            'Seviye ${product.requiredPlayerLevel}',
            hasLevel ? AppColors.green : AppColors.red,
          ),
          SizedBox(height: 5.h),
          _buildRequirementChip(
            Icons.schedule,
            '${product.upgradeDurationHours} saat',
            AppColors.textSecondary,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: product.isMaxQuality
                  ? null
                  : () => _showUpgradeSheet(
                        product,
                        playerLevel: playerLevel,
                        playerCash: playerCash,
                        hasAvailableResearchSlot: hasFreeResearchSlot,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    canUpgrade ? AppColors.gold : AppColors.cardBgLight,
                foregroundColor: canUpgrade ? Colors.black : AppColors.textMuted,
                disabledBackgroundColor: AppColors.cardBgLight,
                disabledForegroundColor: AppColors.textMuted,
                padding: EdgeInsets.symmetric(vertical: 9.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                product.isMaxQuality ? 'MAX' : 'Gelistir',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 9.sp),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
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
  }) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final canStart = hasLevel &&
        hasCash &&
        hasAvailableResearchSlot &&
        !product.isMaxQuality;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeBottomSheet(
        product: product,
        playerLevel: playerLevel,
        playerCash: playerCash,
        canStart: canStart,
        hasActiveResearch: !hasAvailableResearchSlot,
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
        title: 'Arastirma Basladi',
        message: '${result['product_name']} icin gelistirme baslatildi.',
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
    final result = await ref.read(argeActionProvider).completeResearch(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(ref.read(playerArgeCenterProvider).value?.id);
      AppSnackbar.show(
        context,
        title: 'Gelistirme Tamamlandi!',
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
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Aninda Tamamla',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$goldCost yildiz kullanarak arastirmayi aninda tamamlamak istiyor musunuz?',
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

    if (confirm != true || !mounted) return;

    setState(() => _isUpgrading = true);
    final result = await ref.read(argeActionProvider).finishWithGold(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(ref.read(playerArgeCenterProvider).value?.id);
      AppSnackbar.show(
        context,
        title: 'Tamamlandi!',
        message:
            '${result['product_name']} gelistirmesi tamamlandi. ${result['gold_spent']} yildiz harcandi.',
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
      backgroundColor: Colors.transparent,
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
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 14.h),
              _buildSetupRow('Seviye', '${center.level} -> $nextLevel'),
              _buildSetupRow(
                'Arastirma Slotu',
                '${center.maxConcurrentResearches} -> $nextSlots',
              ),
              _buildSetupRow(
                'Sure Bonusu',
                '%${center.durationReductionPct.toStringAsFixed(0)} -> %${nextDurationReduction.toStringAsFixed(0)}',
              ),
              _buildSetupRow('Yukseltme Suresi', '$durationMinutes dakika'),
              _buildSetupRow('Maliyet', _formatMoney(upgradeCost)),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _startCenterUpgrade(center.id);
                  },
                  icon: Icon(Icons.upgrade_rounded, size: 18.sp),
                  label: Text(
                    'Yukseltmeyi Baslat',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
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
    final result = await ref.read(argeActionProvider).startCenterUpgrade(centerId);
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

  Future<void> _finishCenterUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final result = await ref
        .read(argeActionProvider)
        .finishCenterUpgradeWithGold(upgrade.id);

    if (!mounted) return;
    if (result['success'] == true) {
      _refreshCenterEcosystem(upgrade.entityId);
      AppSnackbar.show(
        context,
        title: 'Yukseltme Tamamlandi',
        message:
            'AR-GE merkezi aninda tamamlandi. ${result['gold_spent']} yildiz harcandi.',
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
                  child: Icon(Icons.science_outlined, color: AppColors.blue, size: 30.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AR-GE Merkezi Kur',
                        style: AppTextStyles.h2.copyWith(color: AppColors.gold),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Kalite gelistirmelerini baslatmak icin once arastirma merkezinizi faaliyete gecirin.',
                        style: AppTextStyles.body.copyWith(
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildSetupRow('Kurulum Maliyeti', _formatMoney(setupCost)),
                _buildSetupRow('Insaat Suresi', '$setupDurationMinutes dakika'),
                _buildSetupRow('Baslangic Slotu', '1 arastirma'),
                _buildSetupRow('Sure Bonusu', '%0'),
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
                  hasCash ? Icons.check_circle_outline : Icons.error_outline,
                  color: hasCash ? AppColors.green : AppColors.red,
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    hasCash
                        ? 'Kurulum icin yeterli bakiyeniz var.'
                        : 'Yetersiz bakiye. Mevcut: ${_formatMoney(playerCash)}',
                    style: TextStyle(
                      color: hasCash ? AppColors.green : AppColors.red,
                      fontSize: 12.sp,
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
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.construction_outlined, size: 18.sp),
              label: Text(
                _isCenterSubmitting ? 'Kuruluyor...' : 'AR-GE MERKEZINI KUR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
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
        ? Map<String, dynamic>.from(construction['params'] as Map<String, dynamic>)
        : construction['params'] is Map
            ? Map<String, dynamic>.from(construction['params'] as Map)
            : <String, dynamic>{};
    final finishAt = DateTime.tryParse(construction['finish_at']?.toString() ?? '');
    final remaining = finishAt == null ? Duration.zero : finishAt.difference(now);
    final isDone = !remaining.isNegative && remaining.inSeconds == 0 || (finishAt != null && !finishAt.isAfter(now));
    final remainingMinutes = remaining.isNegative
        ? 0
        : (remaining.inSeconds / 60).ceil();
    final goldCost = remainingMinutes <= 0 ? 0 : ((remainingMinutes + 29) ~/ 30);

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
                  child: Icon(Icons.construction, color: AppColors.gold, size: 30.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (params['name'] ?? 'AR-GE Merkezi').toString(),
                        style: AppTextStyles.h2.copyWith(color: AppColors.gold),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Merkez kurulumu devam ediyor. Insaat tamamlaninca arastirmalar aktif olacak.',
                        style: AppTextStyles.body.copyWith(
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
                  'Kalan Sure',
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
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                isDone ? 'KURULUMU TAMAMLA' : 'KURULUM DEVAM EDIYOR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
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
                icon: Icon(Icons.bolt, size: 16.sp, color: AppColors.gold),
                label: Text(
                  '$goldCost yildiz ile hemen bitir',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
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
        title: 'Kurulum Tamamlandi',
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
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Kurulumu Bitir',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$goldCost yildiz kullanarak AR-GE merkezini hemen kullanima acmak istiyor musunuz?',
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
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Bitir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
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
        title: 'Kurulum Tamamlandi',
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          children: [
            SizedBox(height: 40.h),
            Icon(Icons.search_off, color: AppColors.textMuted, size: 60.sp),
            SizedBox(height: 16.h),
            Text(
              'Urun bulunamadi.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
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
          Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            error.toString(),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
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
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M TL';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K TL';
    return '${amount.toStringAsFixed(0)} TL';
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
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(DateTime finishAt) formatCountdown;

  const _ActiveArgeUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
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
        (upgrade.params['previous_concurrent_researches'] as num?)?.toInt() ?? 1;
    final nextReduction =
        (upgrade.params['next_duration_reduction_pct'] as num?)?.toDouble() ?? 0;
    final prevReduction =
        (upgrade.params['previous_duration_reduction_pct'] as num?)?.toDouble() ?? 0;

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
                child: Icon(Icons.upgrade_rounded, color: AppColors.gold, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merkez Yukseliyor',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${upgrade.name ?? 'AR-GE Merkezi'}  Lv.${upgrade.currentLevel} -> Lv.${upgrade.targetLevel}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCountdown(upgrade.finishAt),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8.h,
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(999.r),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _ArgeUpgradeMeta(
                  label: 'Arastirma Slotu',
                  value: '$prevSlots -> $nextSlots',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _ArgeUpgradeMeta(
                  label: 'Sure Bonusu',
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
                icon: Icon(Icons.flash_on_rounded, size: 16.sp),
                label: Text(
                  '$starCost yildizla bitir',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
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

  const _ArgeUpgradeMeta({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
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

  const _UpgradeBottomSheet({
    required this.product,
    required this.playerLevel,
    required this.playerCash,
    required this.canStart,
    required this.hasActiveResearch,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(5.w, 20.h, 5.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: CachedAssetImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                  errorWidget: Icon(
                    Icons.science,
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
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: List.generate(
                        ArgeProductModel.maxQualityLevel,
                        (index) => Icon(
                          index < product.currentQualityLevel
                              ? Icons.star
                              : Icons.star_border,
                          color: index < product.currentQualityLevel
                              ? AppColors.gold
                              : AppColors.textMuted,
                          size: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Kalite ${product.currentQualityLevel} -> ${product.targetQuality}',
                      style: TextStyle(color: AppColors.blue, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: 16.h),
          _buildRequirementRow(
            icon: Icons.military_tech,
            label: 'Gerekli Seviye',
            value: 'Seviye ${product.requiredPlayerLevel}',
            ok: hasLevel,
            currentValue: '(Mevcut: Lv.$playerLevel)',
          ),
          SizedBox(height: 10.h),
          _buildRequirementRow(
            icon: Icons.account_balance_wallet,
            label: 'Arastirma Maliyeti',
            value: _formatMoney(product.upgradeCost),
            ok: hasCash,
            currentValue: '(Mevcut: ${_formatMoney(playerCash)})',
          ),
          SizedBox(height: 10.h),
          _buildRequirementRow(
            icon: Icons.access_time,
            label: 'Arastirma Suresi',
            value: '${product.upgradeDurationHours} saat',
            ok: true,
            currentValue: 'Her 30 dk = 1 yildiz',
          ),
          SizedBox(height: 16.h),
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Gelistirme tamamlandiginda bu urunu daha yuksek kalite seviyesinde uretebileceksiniz. Arastirma sirasinda para iadesi yapilmaz.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveResearch) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.red,
                    size: 14.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Tum arastirma slotlariniz dolu.',
                      style: TextStyle(color: AppColors.red, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: canStart ? onStart : null,
              icon: Icon(Icons.science, size: 18.sp),
              label: Text(
                canStart ? 'ARASTIRMAYI BASLAT' : 'KOSULLAR KARSILANMADI',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canStart ? AppColors.gold : AppColors.cardBgLight,
                foregroundColor: canStart ? Colors.black : AppColors.textMuted,
                disabledBackgroundColor: AppColors.cardBgLight,
                disabledForegroundColor: AppColors.textMuted,
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

  Widget _buildRequirementRow({
    required IconData icon,
    required String label,
    required String value,
    required bool ok,
    required String currentValue,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: (ok ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            ok ? Icons.check : Icons.close,
            color: ok ? AppColors.green : AppColors.red,
            size: 13.sp,
          ),
        ),
        SizedBox(width: 10.w),
        Icon(icon, color: AppColors.textMuted, size: 14.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: ok ? AppColors.textPrimary : AppColors.red,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentValue,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
            ),
          ],
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M TL';
    }
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K TL';
    return '${amount.toStringAsFixed(0)} TL';
  }
}
