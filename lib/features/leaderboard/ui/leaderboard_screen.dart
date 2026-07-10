import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/leaderboard/data/leaderboard_provider.dart';
import 'package:hard_kapitalizm/features/leaderboard/models/leaderboard_entry_model.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final int _selectedIndex = 4; // Stays on Profile tab high-light
  String _selectedCategory = 'company_value'; // 'company_value', 'level', 'achievement_unlocked_count'

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

  String _formatMetricValue(String category, double value, [int? total]) {
    if (category == 'company_value') {
      return AppMoney.compact(value);
    } else if (category == 'level') {
      return 'Seviye ${value.toInt()}';
    } else if (category == 'achievement_unlocked_count') {
      return '${value.toInt()}/${total ?? 24} Rozet';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider(_selectedCategory));
    final playerRankAsync = ref.watch(currentPlayerRankProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Sıralama ve Liderlik'),
            _buildCategoryTabs(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async {
                  ref.invalidate(leaderboardProvider(_selectedCategory));
                  ref.invalidate(currentPlayerRankProvider(_selectedCategory));
                  await ref.read(leaderboardProvider(_selectedCategory).future);
                  await ref.read(currentPlayerRankProvider(_selectedCategory).future);
                },
                child: leaderboardAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 100.h),
                          Center(
                            child: Text(
                              'Henüz sıralama verisi bulunmuyor.',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      );
                    }

                    final podiumEntries = entries.take(3).toList();
                    final listEntries = entries.skip(3).toList();

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPodium(podiumEntries),
                                if (listEntries.isNotEmpty) ...[
                                  SizedBox(height: 20.h),
                                  Text(
                                    'Sıralama Listesi',
                                    style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.titleLarge),
                                  ),
                                  SizedBox(height: 10.h),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (listEntries.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final entry = listEntries[index];
                                  final rank = index + 4;
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: _buildListRow(rank, entry),
                                  );
                                },
                                childCount: listEntries.length,
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 80.h),
                        ),
                      ],
                    );
                  },
                  loading: () => Center(
                    child: AppLoadingIndicator(color: AppColors.gold),
                  ),
                  error: (err, stack) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 100.h),
                      Center(
                        child: Text(
                          'Hata: $err',
                          style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sticky Bottom Own Player Standing
            playerRankAsync.when(
              data: (rankInfo) {
                if (rankInfo == null || rankInfo.entry == null) {
                  return const SizedBox.shrink();
                }
                return _buildStickyBottomCard(rankInfo.rank, rankInfo.entry!);
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
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

  Widget _buildCategoryTabs() {
    final categories = [
      {'key': 'company_value', 'label': 'Şirket Değeri'},
      {'key': 'level', 'label': 'Seviye'},
      {'key': 'achievement_unlocked_count', 'label': 'Başarımlar'},
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.gold.withValues(alpha: 0.24),
                            AppColors.gold.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  border: isSelected
                      ? Border.all(color: AppColors.gold.withValues(alpha: 0.45))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  cat['label']!,
                  style: AppTextStyles.body.standardCopyWith(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.textSecondary,
                    fontSize: AppTypography.body,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntryModel> topThree) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    final first = topThree[0];
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 2nd Place
        if (second != null) ...[
          Expanded(
            child: _buildPodiumColumn(
              rank: 2,
              entry: second,
              avatarSize: 52.w,
              podiumHeight: 90.h,
              medallionColor: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 8.w),
        ] else
          const Expanded(child: SizedBox.shrink()),

        // 1st Place
        Expanded(
          child: _buildPodiumColumn(
            rank: 1,
            entry: first,
            avatarSize: 66.w,
            podiumHeight: 115.h,
            medallionColor: AppColors.gold,
            isFirst: true,
          ),
        ),
        SizedBox(width: 8.w),

        // 3rd Place
        if (third != null) ...[
          Expanded(
            child: _buildPodiumColumn(
              rank: 3,
              entry: third,
              avatarSize: 46.w,
              podiumHeight: 70.h,
              medallionColor: AppColors.warning,
            ),
          ),
        ] else
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required int rank,
    required LeaderboardEntryModel entry,
    required double avatarSize,
    required double podiumHeight,
    required Color medallionColor,
    bool isFirst = false,
  }) {
    final valueStr = _formatMetricValue(
      _selectedCategory,
      _selectedCategory == 'company_value'
          ? entry.companyValue
          : _selectedCategory == 'level'
              ? entry.level.toDouble()
              : entry.achievementUnlockedCount.toDouble(),
      entry.achievementTotalCount,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar stack
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: medallionColor,
                  width: isFirst ? 3.w : 2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: medallionColor.withValues(alpha: 0.28),
                    blurRadius: isFirst ? 14.r : 8.r,
                    spreadRadius: 1.r,
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedAssetImage(
                  fileName: entry.avatarId,
                  fit: BoxFit.cover,
                  placeholder: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.large),
                  errorWidget: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.large),
                ),
              ),
            ),
            if (isFirst)
              Positioned(
                top: -16.h,
                child: Icon(
                  AppIcons.emojiEventsRounded,
                  color: AppColors.gold,
                  size: AppIconSizes.medium,
                ),
              ),
            Positioned(
              bottom: -6.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: medallionColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.background, width: 1.w),
                ),
                child: Text(
                  '#$rank',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textOnAccent,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        // Name & Company
        Text(
          entry.playerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: isFirst ? 13.sp : 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          entry.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.caption,
          ),
        ),
        SizedBox(height: 6.h),
        // Value indicator
        Text(
          valueStr,
          style: AppTextStyles.body.standardCopyWith(
            color: isFirst ? AppColors.gold : AppColors.goldLight,
            fontSize: isFirst ? 12.sp : 10.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6.h),
        // The podium visual pillar
        Container(
          width: double.infinity,
          height: podiumHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.cardBgLight.withValues(alpha: 0.8),
                AppColors.cardBg.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: medallionColor.withValues(alpha: 0.35),
              width: 1.w,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.15,
              child: Text(
                '$rank',
                style: AppTextStyles.largeTitle.standardCopyWith(
                  color: medallionColor,
                  fontSize: isFirst ? 42.sp : 32.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListRow(int rank, LeaderboardEntryModel entry) {
    final valueStr = _formatMetricValue(
      _selectedCategory,
      _selectedCategory == 'company_value'
          ? entry.companyValue
          : _selectedCategory == 'level'
              ? entry.level.toDouble()
              : entry.achievementUnlockedCount.toDouble(),
      entry.achievementTotalCount,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Rank index
          SizedBox(
            width: 32.w,
            child: Text(
              '#$rank',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Avatar
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.w),
            ),
            child: ClipOval(
              child: CachedAssetImage(
                fileName: entry.avatarId,
                fit: BoxFit.cover,
                placeholder: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.regular),
                errorWidget: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.regular),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Player & Company names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  entry.companyName,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                  ),
                ),
              ],
            ),
          ),
          // Value
          Text(
            valueStr,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.gold,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomCard(int rank, LeaderboardEntryModel entry) {
    final valueStr = _formatMetricValue(
      _selectedCategory,
      _selectedCategory == 'company_value'
          ? entry.companyValue
          : _selectedCategory == 'level'
              ? entry.level.toDouble()
              : entry.achievementUnlockedCount.toDouble(),
      entry.achievementTotalCount,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.5.w,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 16.r,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
            child: Text(
              '#$rank',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Avatar
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5.w),
            ),
            child: ClipOval(
              child: CachedAssetImage(
                fileName: entry.avatarId,
                fit: BoxFit.cover,
                placeholder: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.medium),
                errorWidget: Icon(AppIcons.person, color: AppColors.gold, size: AppIconSizes.medium),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${entry.playerName} (Ben)',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  entry.companyName,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.label,
                  ),
                ),
              ],
            ),
          ),
          // Value
          Text(
            valueStr,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.gold,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
