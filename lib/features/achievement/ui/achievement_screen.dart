import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
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
  final Set<String> _claimingAchievementIds = <String>{};

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

  Future<void> _claimAchievementReward(AchievementBadgeModel badge) async {
    if (_claimingAchievementIds.contains(badge.id)) return;

    setState(() => _claimingAchievementIds.add(badge.id));
    AppHaptic.heavy();

    try {
      final result = await ref
          .read(achievementActionProvider)
          .claimAchievementReward(badge.id);

      if (!mounted) return;

      if (result['success'] != true) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: (result['message'] ?? 'Başarım ödülü alınamadı.').toString(),
          type: SnackbarType.error,
        );
        return;
      }

      showExperienceFeedbackFromResult(context, result);

      final rewardMap = result['reward'] is Map<String, dynamic>
          ? result['reward'] as Map<String, dynamic>
          : result['reward'] is Map
              ? Map<String, dynamic>.from(result['reward'] as Map)
              : const <String, dynamic>{};

      final cash = (rewardMap['cash'] as num?)?.toDouble() ?? 0;
      final gold = (rewardMap['gold'] as num?)?.toInt() ?? 0;
      final xp = (rewardMap['xp'] as num?)?.toInt() ?? 0;
      final rewardParts = <String>[];

      if (cash > 0) rewardParts.add('+${AppMoney.full(cash)}');
      if (gold > 0) rewardParts.add('+$gold Altın');
      if (xp > 0) rewardParts.add('+$xp XP');

      AppSnackbar.show(
        context,
        title: '🏆 Başarım Ödülü Alındı!',
        message: rewardParts.isEmpty
            ? 'Tebrikler! Başarım ödülünüz hesabınıza aktarıldı.'
            : rewardParts.join(' | '),
        type: SnackbarType.success,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: 'Ödül alınırken bir hata oluştu: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claimingAchievementIds.remove(badge.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(playerAchievementDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Başarılar ve Rozetler'),
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
                            claimableCount: dashboard.claimableCount,
                            totalCount: dashboard.totalCount,
                          ),
                          SizedBox(height: 20.h),
                          _buildCategoryFilter(
                            categories,
                            selectedCategory,
                          ),
                          SizedBox(height: 16.h),
                          _buildSectionTitle(
                            'Odaktaki Başarılar',
                            dashboard.claimableCount > 0
                                ? '${dashboard.claimableCount} adet ödül toplanmaya hazır!'
                                : 'Yakında açılabilecek rozetler',
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
                        child: AppLoadingIndicator(color: AppColors.gold),
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
    required int claimableCount,
    required int totalCount,
  }) {
    final ratio = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: claimableCount > 0 ? AppColors.gold : AppColors.gold.withValues(alpha: 0.28),
          width: claimableCount > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          if (claimableCount > 0)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rozet İlerlemesi', style: AppTextStyles.h2),
              if (claimableCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$claimableCount Ödül Hazır!',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '$unlockedCount / $totalCount rozet açıldı',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: AppProgressBar(
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
              category == 'all' ? 'Tüm Kategoriler' : _categoryLabel(category);

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
                  style: AppTextStyles.label.standardCopyWith(
                    color: isSelected ? AppColors.gold : AppColors.white,
                    fontSize: AppTypography.bodySmall,
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
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
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
    final isClaiming = _claimingAchievementIds.contains(badge.id);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(compact ? 12.w : 14.w),
      decoration: BoxDecoration(
        gradient: badge.isUnlocked
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.12),
                  AppColors.cardBg,
                ],
              )
            : null,
        color: badge.isUnlocked ? null : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: badge.isClaimable
              ? AppColors.gold
              : badge.isUnlocked
                  ? color.withValues(alpha: 0.65)
                  : color.withValues(alpha: 0.28),
          width: badge.isClaimable || badge.isUnlocked ? 1.5 : 1,
        ),
        boxShadow: [
          if (badge.isClaimable)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else if (badge.isUnlocked)
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
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
            child: Icon(icon, color: color, size: compact ? AppIconSizes.medium : AppIconSizes.large),
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
                      badge.isClaimable
                          ? 'Ödül Hazır!'
                          : badge.isClaimed
                              ? 'Ödül Alındı'
                              : badge.progressText,
                      badge.isClaimable
                          ? AppColors.gold
                          : badge.isClaimed
                              ? AppColors.green
                              : color,
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  badge.title,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: compact ? 13.sp : 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  badge.description,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: compact ? 11.sp : 12.sp,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 8.h),
                if (!badge.isUnlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999.r),
                    child: AppProgressBar(
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
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.goldLight,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge.isClaimable) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isClaiming ? null : () => _claimAchievementReward(badge),
                      icon: isClaiming
                          ? SizedBox(
                              width: 14.w,
                              height: 14.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Icon(AppIcons.cardGiftcardRounded, size: 16.sp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        elevation: 3,
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      label: Text(
                        isClaiming ? 'Alınıyor...' : 'Ödülü Al!',
                        style: AppTextStyles.button.standardCopyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ],
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
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
        style: AppTextStyles.body.standardCopyWith(
          color: AppColors.textMuted,
          fontSize: AppTypography.body,
        ),
      ),
    );
  }

  IconData _badgeIcon(String key) {
    switch (key) {
      case 'store':
        return AppIcons.storefrontRounded;
      case 'warehouse':
        return AppIcons.warehouseRounded;
      case 'factory':
        return AppIcons.precisionManufacturingRounded;
      case 'field':
      case 'farm':
        return AppIcons.agricultureRounded;
      case 'mine':
        return AppIcons.landscapeRounded;
      case 'builder':
        return AppIcons.handymanRounded;
      case 'trade':
        return AppIcons.pointOfSaleRounded;
      case 'truck':
        return AppIcons.localShippingRounded;
      case 'science':
        return AppIcons.scienceRounded;
      case 'upgrade':
        return AppIcons.trendingUpRounded;
      case 'crown':
        return AppIcons.workspacePremiumRounded;
      default:
        return AppIcons.militaryTechRounded;
    }
  }

  Color _badgeColor(String key) {
    return AppColorPresets.badge(key);
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
