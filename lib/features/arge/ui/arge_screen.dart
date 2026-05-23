import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/arge/data/arge_provider.dart';
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

  static const _unitFilters = [
    ('TUMU', 'Tümü'),
    ('FABRIKA', 'Fabrika'),
    ('TARLA', 'Tarla'),
    ('CIFTLIK', 'Çiftlik'),
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
      case 4:
        context.go('/profile');
        break;
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(argeProductsProvider);
  }

  List<ArgeProductModel> _filter(List<ArgeProductModel> products) {
    return products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.urunAdi.toLowerCase().contains(_searchQuery);
      final matchesUnit =
          _selectedUnit == 'TUMU' || p.uretimBirimi == _selectedUnit;
      return matchesSearch && matchesUnit;
    }).toList();
  }

  // ──────────────────────────────────────────────────────── BUILD ─────────────

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(argeProductsProvider);
    final researchAsync = ref.watch(activeArgeResearchProvider);
    final player = ref.watch(playerStreamProvider).value;

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
              child: productsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, _) => _buildError(e),
                data: (products) => RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.gold,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats banner
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                          child: _buildStatsBanner(products, player),
                        ),
                      ),

                      // Active research card
                      SliverToBoxAdapter(
                        child: researchAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (research) => research == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                                  child: LiveActiveResearchCard(
                                    research: research,
                                    isUpgrading: _isUpgrading,
                                    onCollect: _onCollect,
                                    onFinishWithGold: _onFinishWithGold,
                                  ),
                                ),
                        ),
                      ),

                      // Search bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                          child: _buildSearchBar(),
                        ),
                      ),

                      // Unit filter chips
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, 10.h, 0, 0),
                          child: _buildUnitFilters(),
                        ),
                      ),

                      // Product grid
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 24.h),
                        sliver: _buildProductGrid(
                          _filter(products),
                          player,
                          researchAsync.value,
                        ),
                      ),
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

  // ─── Stats Banner ────────────────────────────────────────────────────────────

  Widget _buildStatsBanner(
    List<ArgeProductModel> products,
    dynamic player,
  ) {
    final upgraded = products.where((p) => p.currentQualityLevel > 1).length;
    final maxed = products.where((p) => p.isMaxQuality).length;
    final cash = double.tryParse(player?.cash?.toString() ?? '0') ?? 0;

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
          _buildStatItem(Icons.science, AppColors.blue, 'Geliştirilen',
              '$upgraded ürün', Colors.white),
          Container(
            width: 1.w,
            height: 36.h,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
          _buildStatItem(Icons.star, AppColors.gold, 'Max Seviye',
              '$maxed ürün', AppColors.goldLight),
          Container(
            width: 1.w,
            height: 36.h,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
          _buildStatItem(Icons.account_balance_wallet, AppColors.green,
              'Bakiye', _formatMoney(cash), AppColors.green),
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
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
                  Text(label,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 9.sp)),
                  SizedBox(height: 2.h),
                  Text(value,
                      style: TextStyle(
                          color: valueColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Research Card ─────────────────────────────────────────────────

  Widget _buildActiveResearchCard(ArgeResearchModel research) {
    final remaining = research.remaining;
    final isDone = research.isDone;
    final goldCost = research.goldCostToFinish;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A1A3A),
            AppColors.cardBgLight.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(
          color: isDone
              ? AppColors.green.withValues(alpha: 0.7)
              : AppColors.blue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? AppColors.green : AppColors.blue)
                .withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.science, color: AppColors.blue, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Araştırma Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      research.productName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildQualityBadge(research.currentQuality, research.targetQuality),
            ],
          ),
          SizedBox(height: 12.h),

          // Progress bar
          _buildResearchProgressBar(research),
          SizedBox(height: 12.h),

          // Timer row
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.access_time,
                color: isDone ? AppColors.green : AppColors.textSecondary,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                isDone
                    ? 'Tamamlandı! Alabilirsin.'
                    : _formatDuration(remaining),
                style: TextStyle(
                  color: isDone ? AppColors.green : AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (isDone)
                _buildActionButton(
                  label: 'TOPLA',
                  icon: Icons.download_done,
                  color: AppColors.green,
                  onTap: () => _onCollect(research.id),
                ),
            ],
          ),
          // Gold speedup button
          if (!isDone && goldCost > 0) ...[
            SizedBox(height: 10.h),
            GoldFinishButton(
              starCost: goldCost,
              onPressed: _isUpgrading
                  ? null
                  : () => _onFinishWithGold(research.id, goldCost),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResearchProgressBar(ArgeResearchModel research) {
    final totalDuration = research.finishAt.difference(research.startedAt);
    final elapsed = DateTime.now().toUtc().difference(research.startedAt);
    final ratio = (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
    final isDone = research.isDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kalite ${research.currentQuality} → ${research.targetQuality}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  color: isDone ? AppColors.green : AppColors.blue,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(
          height: 8.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.r),
                gradient: LinearGradient(
                  colors: isDone
                      ? [AppColors.green.withValues(alpha: 0.7), AppColors.green]
                      : [
                          AppColors.blue.withValues(alpha: 0.7),
                          AppColors.blue,
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDone ? AppColors.green : AppColors.blue)
                        .withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(int current, int target) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$current',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold)),
          Icon(Icons.arrow_forward, color: AppColors.blue, size: 12.sp),
          Text('$target',
              style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold)),
          SizedBox(width: 3.w),
          Icon(Icons.star, color: AppColors.gold, size: 11.sp),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUpgrading ? null : onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 13.sp),
              SizedBox(width: 5.w),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search Bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      height: 42.h,
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Ürün ara...',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          prefixIcon:
              Icon(Icons.search, color: AppColors.textMuted, size: 18.sp),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: Icon(Icons.close,
                      color: AppColors.textMuted, size: 16.sp),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        ),
      ),
    );
  }

  // ─── Unit Filters ────────────────────────────────────────────────────────────

  Widget _buildUnitFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        children: _unitFilters.map((filter) {
          final key = filter.$1;
          final label = filter.$2;
          final isSelected = _selectedUnit == key;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedUnit = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.cardBg,
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
                            color: AppColors.gold.withValues(alpha: 0.12),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.goldLight
                        : AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Product Grid ─────────────────────────────────────────────────────────

  Widget _buildProductGrid(
    List<ArgeProductModel> products,
    dynamic player,
    ArgeResearchModel? activeResearch,
  ) {
    if (products.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    final playerLevel = (player?.level as num?)?.toInt() ?? 1;
    final cash =
        double.tryParse(player?.cash?.toString() ?? '0') ?? 0;
    final hasActiveResearch = activeResearch != null;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return _buildProductCard(
            product,
            playerLevel: playerLevel,
            playerCash: cash,
            hasActiveResearch: hasActiveResearch,
            isBeingResearched:
                activeResearch?.productId == product.id,
          );
        },
        childCount: products.length,
      ),
    );
  }

  Widget _buildProductCard(
    ArgeProductModel product, {
    required int playerLevel,
    required double playerCash,
    required bool hasActiveResearch,
    required bool isBeingResearched,
  }) {
    final isMax = product.isMaxQuality;
    final hasLevel = product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final canUpgrade =
        !isMax && hasLevel && hasCash && !hasActiveResearch;

    // Renk durumu
    Color borderColor;
    if (isBeingResearched) {
      borderColor = AppColors.blue.withValues(alpha: 0.7);
    } else if (isMax) {
      borderColor = AppColors.green.withValues(alpha: 0.4);
    } else if (canUpgrade) {
      borderColor = AppColors.borderGold;
    } else {
      borderColor = AppColors.border.withValues(alpha: 0.3);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: isMax
            ? null
            : () => _showUpgradeSheet(
                  product,
                  playerLevel: playerLevel,
                  playerCash: playerCash,
                  hasActiveResearch: hasActiveResearch,
                ),
        borderRadius: BorderRadius.circular(14.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: borderColor),
            gradient: isBeingResearched
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cardBg,
                      AppColors.blue.withValues(alpha: 0.08),
                    ],
                  )
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    _buildProductIcon(product, isMax, isBeingResearched),
                    SizedBox(height: 8.h),

                    // Name
                    Text(
                      product.urunAdi,
                      style: TextStyle(
                        color: isMax
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),

                    // Quality stars
                    _buildQualityStars(product.currentQualityLevel),
                    SizedBox(height: 8.h),

                    // Bottom area
                    _buildCardBottom(
                      product,
                      isMax: isMax,
                      hasLevel: hasLevel,
                      hasCash: hasCash,
                      hasActiveResearch: hasActiveResearch,
                      isBeingResearched: isBeingResearched,
                    ),
                  ],
                ),
              ),

              // Lock overlay
              if (!isMax &&
                  (!hasLevel || !hasCash || hasActiveResearch) &&
                  !isBeingResearched)
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock,
                      color: AppColors.textMuted,
                      size: 11.sp,
                    ),
                  ),
                ),

              // MAX badge
              if (isMax)
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'MAX',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductIcon(
      ArgeProductModel product, bool isMax, bool isBeingResearched) {
    final glowColor = isBeingResearched
        ? AppColors.blue
        : isMax
            ? AppColors.green
            : AppColors.gold;

    return Container(
      width: 56.w,
      height: 56.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(
          color: glowColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CachedAssetImage(
        fileName: product.urunIconu,
        fit: BoxFit.contain,
        errorWidget: Icon(Icons.science, color: AppColors.gold, size: 24.sp),
      ),
    );
  }

  Widget _buildQualityStars(int level) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(ArgeProductModel.maxQualityLevel, (i) {
        final filled = i < level;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: filled
              ? AppColors.gold
              : AppColors.textMuted.withValues(alpha: 0.5),
          size: 13.sp,
        );
      }),
    );
  }

  Widget _buildCardBottom(
    ArgeProductModel product, {
    required bool isMax,
    required bool hasLevel,
    required bool hasCash,
    required bool hasActiveResearch,
    required bool isBeingResearched,
  }) {
    if (isBeingResearched) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 10.w,
              height: 10.w,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.blue,
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              'Araştırılıyor',
              style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isMax) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          'Maksimum Kalite',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.green.withValues(alpha: 0.7),
              fontSize: 10.sp,
              fontWeight: FontWeight.w600),
        ),
      );
    }

    // Requirement hint
    if (!hasLevel) {
      return _buildRequirementChip(
        Icons.lock,
        'Seviye ${product.requiredPlayerLevel} gerekli',
        AppColors.red,
      );
    }

    if (hasActiveResearch) {
      return _buildRequirementChip(
        Icons.hourglass_top,
        'Araştırma devam ediyor',
        AppColors.textMuted,
      );
    }

    // Can upgrade — show cost
    final cost = product.upgradeCost;
    final hours = product.upgradeDurationHours;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 5.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.2),
                AppColors.goldDark.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(8.r),
            border:
                Border.all(color: AppColors.gold.withValues(alpha: hasCash ? 0.6 : 0.2)),
          ),
          child: Column(
            children: [
              Text(
                _formatMoney(cost),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasCash ? AppColors.goldLight : AppColors.red,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '⏱ ${hours}sa',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
              ),
            ],
          ),
        ),
      ],
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

  // ─── Upgrade Bottom Sheet ─────────────────────────────────────────────────

  void _showUpgradeSheet(
    ArgeProductModel product, {
    required int playerLevel,
    required double playerCash,
    required bool hasActiveResearch,
  }) {
    final hasLevel =
        product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);
    final canStart = hasLevel && hasCash && !hasActiveResearch && !product.isMaxQuality;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeBottomSheet(
        product: product,
        playerLevel: playerLevel,
        playerCash: playerCash,
        canStart: canStart,
        hasActiveResearch: hasActiveResearch,
        onStart: () async {
          Navigator.of(context).pop();
          await _onStartResearch(product.id);
        },
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _onStartResearch(String productId) async {
    setState(() => _isUpgrading = true);
    final result =
        await ref.read(argeActionProvider).startResearch(productId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      ref.invalidate(argeProductsProvider);
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
    final result =
        await ref.read(argeActionProvider).completeResearch(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      ref.invalidate(argeProductsProvider);
      AppSnackbar.show(
        context,
        title: 'Geliştirme Tamamlandı!',
        message:
            '${result['product_name']} kalite ${result['new_quality_level']} seviyesine ulaştı.',
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

  Future<void> _onFinishWithGold(String researchId, int goldCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text('Anında Tamamla',
            style: TextStyle(
                color: AppColors.goldLight,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold)),
        content: Text(
          '$goldCost ⭐ yıldız kullanarak araştırmayı anında tamamlamak istiyor musunuz?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13.sp)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Tamamla',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13.sp)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isUpgrading = true);
    final result =
        await ref.read(argeActionProvider).finishWithGold(researchId);
    setState(() => _isUpgrading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      ref.invalidate(argeProductsProvider);
      AppSnackbar.show(
        context,
        title: 'Tamamlandı!',
        message:
            '${result['product_name']} geliştirmesi tamamlandı. ${result['gold_spent']} ⭐ harcandı.',
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          children: [
            SizedBox(height: 40.h),
            Icon(Icons.search_off, color: AppColors.textMuted, size: 60.sp),
            SizedBox(height: 16.h),
            Text('Ürün bulunamadı.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 14.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
          SizedBox(height: 12.h),
          Text(e.toString(),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
              textAlign: TextAlign.center),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBgLight),
            child:
                Text('Tekrar Dene', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M₺';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K₺';
    return '${amount.toStringAsFixed(0)}₺';
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─── Upgrade Bottom Sheet ─────────────────────────────────────────────────────

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
    final hasLevel =
        product.hasLevelRequirement(playerLevel: playerLevel);
    final hasCash = product.hasCashRequirement(playerCash: playerCash);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          // Product header
          Row(
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        blurRadius: 12),
                  ],
                ),
                child: CachedAssetImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                  errorWidget: Icon(Icons.science,
                      color: AppColors.gold, size: 28.sp),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.urunAdi,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Row(
                      children: List.generate(
                          ArgeProductModel.maxQualityLevel, (i) {
                        return Icon(
                          i < product.currentQualityLevel
                              ? Icons.star
                              : Icons.star_border,
                          color: i < product.currentQualityLevel
                              ? AppColors.gold
                              : AppColors.textMuted,
                          size: 16.sp,
                        );
                      }),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Kalite ${product.currentQualityLevel} → ${product.targetQuality}',
                      style: TextStyle(
                          color: AppColors.blue, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: 16.h),

          // Requirements
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
            label: 'Araştırma Maliyeti',
            value: _formatMoney(product.upgradeCost),
            ok: hasCash,
            currentValue:
                '(Mevcut: ${_formatMoney(playerCash)})',
          ),
          SizedBox(height: 10.h),
          _buildRequirementRow(
            icon: Icons.access_time,
            label: 'Araştırma Süresi',
            value: '${product.upgradeDurationHours} saat',
            ok: true,
            currentValue: 'Her 30 dk = 1 ⭐',
          ),

          SizedBox(height: 16.h),
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: 14.h),

          // Info
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.gold, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Geliştirme tamamlandığında bu ürünü daha yüksek kalite '
                    'seviyesinde üretebileceksiniz. Araştırma sırasında para iadesi yapılmaz.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.sp),
                  ),
                ),
              ],
            ),
          ),

          if (hasActiveResearch) ...[
            SizedBox(height: 12.h),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.red, size: 14.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Zaten devam eden bir araştırmanız var.',
                      style: TextStyle(
                          color: AppColors.red, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 20.h),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton.icon(
              onPressed: canStart ? onStart : null,
              icon: Icon(Icons.science, size: 18.sp),
              label: Text(
                canStart ? 'ARAŞTIRMAYI BAŞLAT' : 'KOŞULLAR KARŞILANMADI',
                style: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canStart ? AppColors.gold : AppColors.cardBgLight,
                foregroundColor: canStart ? Colors.black : AppColors.textMuted,
                disabledBackgroundColor: AppColors.cardBgLight,
                disabledForegroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
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
            color: (ok ? AppColors.green : AppColors.red)
                .withValues(alpha: 0.12),
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
        Text(label,
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 12.sp)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    color: ok ? AppColors.textPrimary : AppColors.red,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold)),
            Text(currentValue,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10.sp)),
          ],
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M₺';
    }
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K₺';
    return '${amount.toStringAsFixed(0)}₺';
  }
}
