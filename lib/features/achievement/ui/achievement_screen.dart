import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';

class AchievementScreen extends ConsumerStatefulWidget {
  const AchievementScreen({super.key});

  @override
  ConsumerState<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends ConsumerState<AchievementScreen> {
  final int _selectedIndex = 4;
  String _selectedCategory = 'all';

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
    final dashboardAsync = ref.watch(playerAchievementDashboardProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Basarilar ve Rozetler'),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async {
                  ref.invalidate(playerAchievementDashboardProvider);
                  await ref.read(playerAchievementDashboardProvider.future);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: dashboardAsync.when(
                    data: (dashboard) {
                      final categories = _achievementCategories(
                        dashboard.activeAchievements,
                        dashboard.unlockedAchievements,
                      );
                      final selectedCategory =
                          categories.contains(_selectedCategory)
                              ? _selectedCategory
                              : 'all';
                      final activeItems = _filterByCategory(
                        dashboard.activeAchievements,
                        selectedCategory,
                      );
                      final unlockedItems = _filterByCategory(
                        dashboard.unlockedAchievements,
                        selectedCategory,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(
                            unlockedCount: dashboard.unlockedCount,
                            totalCount: dashboard.totalCount,
                          ),
                          SizedBox(height: 20.h),
                          _buildCategoryFilter(
                            categories,
                            selectedCategory,
                          ),
                          SizedBox(height: 16.h),
                          _buildSectionTitle(
                            'Odaktaki Basarilar',
                            'Yakinda acilabilecek rozetler',
                          ),
                          SizedBox(height: 10.h),
                          if (activeItems.isEmpty)
                            _buildEmptyState('Bu filtre icin aktif basari yok.')
                          else
                            ...activeItems.map(_buildAchievementCard),
                          SizedBox(height: 20.h),
                          _buildSectionTitle(
                            'Acilan Rozetler',
                            'Su ana kadar kazandigin kalici basarilar',
                          ),
                          SizedBox(height: 10.h),
                          if (unlockedItems.isEmpty)
                            _buildEmptyState('Henuz bu filtre icin rozet yok.')
                          else
                            ...unlockedItems.map(
                              (badge) =>
                                  _buildAchievementCard(badge, compact: true),
                            ),
                        ],
                      );
                    },
                    loading: () => Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 120.h),
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    ),
                    error: (error, _) =>
                        _buildEmptyState('Basarilar yuklenemedi: $error'),
                  ),
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required int unlockedCount,
    required int totalCount,
  }) {
    final ratio = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rozet Ilerlemesi', style: AppTextStyles.h2),
          SizedBox(height: 8.h),
          Text(
            '$unlockedCount / $totalCount rozet acildi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10.h,
              backgroundColor: AppColors.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(
    List<String> categories,
    String selectedCategory,
  ) {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          final label =
              category == 'all' ? 'Tum Kategoriler' : _categoryLabel(category);

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.14)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h2),
        SizedBox(height: 3.h),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
        ),
      ],
    );
  }

  List<AchievementBadgeModel> _filterByCategory(
    List<AchievementBadgeModel> items,
    String selectedCategory,
  ) {
    if (selectedCategory == 'all') return items;
    return items.where((item) => item.category == selectedCategory).toList();
  }

  List<String> _achievementCategories(
    List<AchievementBadgeModel> active,
    List<AchievementBadgeModel> unlocked,
  ) {
    return <String>{
      'all',
      ...active.map((item) => item.category),
      ...unlocked.map((item) => item.category),
    }.toList();
  }

  Widget _buildAchievementCard(
    AchievementBadgeModel badge, {
    bool compact = false,
  }) {
    final color = _badgeColor(badge.badgeColor);
    final icon = _badgeIcon(badge.badgeKey);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(compact ? 12.w : 14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 42.w : 50.w,
            height: compact ? 42.w : 50.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: compact ? 20.sp : 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildBadgeMetaChip(badge.categoryLabel, color),
                    _buildBadgeMetaChip(
                      badge.isUnlocked ? 'Acildi' : badge.progressText,
                      badge.isUnlocked ? AppColors.green : color,
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  badge.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 13.sp : 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  badge.description,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: compact ? 11.sp : 12.sp,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 8.h),
                if (!badge.isUnlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999.r),
                    child: LinearProgressIndicator(
                      value: badge.progressRatio.clamp(0.0, 1.0),
                      minHeight: 7.h,
                      backgroundColor: AppColors.border.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
                Text(
                  badge.compactRewardText,
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeMetaChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
      ),
    );
  }

  IconData _badgeIcon(String key) {
    switch (key) {
      case 'store':
        return Icons.storefront_rounded;
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'factory':
        return Icons.precision_manufacturing_rounded;
      case 'field':
      case 'farm':
        return Icons.agriculture_rounded;
      case 'mine':
        return Icons.landscape_rounded;
      case 'builder':
        return Icons.handyman_rounded;
      case 'trade':
        return Icons.point_of_sale_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'upgrade':
        return Icons.trending_up_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  Color _badgeColor(String key) {
    switch (key) {
      case 'blue':
        return Colors.lightBlueAccent;
      case 'red':
        return Colors.redAccent;
      case 'green':
        return Colors.greenAccent;
      case 'lime':
        return Colors.lightGreenAccent;
      case 'slate':
        return Colors.blueGrey;
      case 'orange':
        return Colors.orangeAccent;
      case 'deepOrange':
        return Colors.deepOrangeAccent;
      case 'cyan':
        return Colors.cyanAccent;
      case 'purple':
        return Colors.purpleAccent;
      case 'teal':
        return Colors.tealAccent;
      case 'amber':
      default:
        return Colors.amberAccent;
    }
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'expansion':
        return 'Buyume';
      case 'trade':
        return 'Ticaret';
      case 'logistics':
        return 'Lojistik';
      case 'research':
        return 'Arastirma';
      case 'mastery':
      default:
        return 'Ustalik';
    }
  }
}
