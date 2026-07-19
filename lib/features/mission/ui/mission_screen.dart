import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_dashboard_model.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';
import 'package:hard_kapitalizm/features/mission/data/daily_streak_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

enum _MissionTab {
  main('Ana Görev'),
  daily('Günlük'),
  weekly('Haftalık'),
  achievements('Başarılar');

  const _MissionTab(this.label);
  final String label;
}

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  _MissionTab? _selectedTab;
  final Set<String> _claimingMissionIds = <String>{};

  bool _mainClaimedExpanded = false;
  bool _dailyClaimedExpanded = false;
  bool _weeklyClaimedExpanded = false;
  bool _achievementsClaimedExpanded = false;

  Future<void> _refresh() async {
    ref.invalidate(playerMissionDashboardProvider);
    await ref.read(playerMissionDashboardProvider.future);
  }

  Future<void> _claimMissionReward(PlayerMissionModel mission) async {
    if (_claimingMissionIds.contains(mission.id)) return;

    setState(() => _claimingMissionIds.add(mission.id));
    try {
      final result = await ref
          .read(missionActionProvider)
          .claimMissionReward(mission.id);

      if (!mounted) return;

      if (result['success'] != true) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: (result['message'] ?? 'Görev ödülü alınamadı.').toString(),
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

      if (cash > 0) rewardParts.add('+${_formatMoney(cash)} Nakit');
      if (gold > 0) rewardParts.add('+$gold Altın');
      if (xp > 0) rewardParts.add('+$xp XP');

      AppSnackbar.show(
        context,
        title: 'Görev Tamamlandı',
        message: rewardParts.isEmpty
            ? 'Ödül başarıyla alındı.'
            : rewardParts.join(' | '),
        type: SnackbarType.success,
      );
    } finally {
      if (mounted) {
        setState(() => _claimingMissionIds.remove(mission.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(playerMissionDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Görevler'),
            Expanded(
              child: dashboardAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, _) => _buildErrorState(error.toString()),
                data: (dashboard) {
                  if (!dashboard.success || !dashboard.hasAnyMission) {
                    return _buildEmptyState();
                  }

                  if (_selectedTab == null) {
                    final hasActiveMain =
                        dashboard.mainMission != null &&
                        !dashboard.mainMission!.isClaimed;
                    _selectedTab = hasActiveMain
                        ? _MissionTab.main
                        : _MissionTab.daily;
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.gold,
                    backgroundColor: AppColors.cardBg,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                      children: [
                        _buildHeader(dashboard),
                        SizedBox(height: 14.h),
                        _buildCustomTabBar(dashboard),
                        SizedBox(height: 14.h),
                        ..._buildTabContent(dashboard),
                      ],
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

  Widget _buildHeader(PlayerMissionDashboardModel dashboard) {
    final completed = dashboard.completedCount;
    final total = dashboard.totalCount;
    final ratio = dashboard.completionRatio;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AppProgressRing(
                value: ratio,
                diameter: 44.w,
                strokeWidth: 4.w,
                semanticsLabel: 'Gorev tamamlama orani',
              ),
              Icon(
                dashboard.claimableCount > 0
                    ? AppIcons.cardGiftcardRounded
                    : AppIcons.emojiEventsRounded,
                color: dashboard.claimableCount > 0
                    ? AppColors.green
                    : AppColors.gold,
                size: AppIconSizes.medium,
              ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görev İlerlemesi',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Toplam $completed / $total görev tamamlandı',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                  ),
                ),
              ],
            ),
          ),
          if (dashboard.claimableCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.checkCircleRounded,
                    color: AppColors.green,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '${dashboard.claimableCount} Ödül',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.green,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar(PlayerMissionDashboardModel dashboard) {
    final mainBadge = (dashboard.mainMission?.claimable == true) ? 1 : 0;
    final dailyBadge = dashboard.dailyClaimableCount;
    final weeklyBadge = dashboard.weeklyClaimableCount;
    final achievementBadge = dashboard.sideMissions
        .where((m) => m.claimable)
        .length;

    return Container(
      height: 42.h,
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: _MissionTab.values.map((tab) {
          final isSelected = tab == _selectedTab;

          int badgeCount = 0;
          if (tab == _MissionTab.main) badgeCount = mainBadge;
          if (tab == _MissionTab.daily) badgeCount = dailyBadge;
          if (tab == _MissionTab.weekly) badgeCount = weeklyBadge;
          if (tab == _MissionTab.achievements) badgeCount = achievementBadge;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = tab;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : AppColors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab.label,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      SizedBox(width: 5.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textOnAccent,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildTabContent(PlayerMissionDashboardModel dashboard) {
    if (_selectedTab == null) return const [];

    switch (_selectedTab!) {
      case _MissionTab.main:
        final main = dashboard.mainMission;
        if (main == null) {
          return [_buildMainMissionEmptyState()];
        }

        final active = !main.isClaimed ? main : null;
        final claimed = main.isClaimed ? [main] : <PlayerMissionModel>[];

        return [
          if (active != null)
            _buildMissionCard(active, featured: true)
          else
            _buildMainMissionEmptyState(),
          _buildCollapsibleCompletedSection(
            claimed,
            _mainClaimedExpanded,
            () => setState(() => _mainClaimedExpanded = !_mainClaimedExpanded),
          ),
        ];

      case _MissionTab.daily:
        final active = dashboard.dailyMissions
            .where((m) => !m.isClaimed)
            .toList();
        final claimed = dashboard.dailyMissions
            .where((m) => m.isClaimed)
            .toList();

        return [
          _buildDailyStreakCalendarCard(),
          if (active.isEmpty)
            _buildDailiesAllCompletedState(claimed.isNotEmpty)
          else
            ...active.map((m) => _buildMissionCard(m)),
          _buildCollapsibleCompletedSection(
            claimed,
            _dailyClaimedExpanded,
            () =>
                setState(() => _dailyClaimedExpanded = !_dailyClaimedExpanded),
          ),
        ];

      case _MissionTab.weekly:
        final active = dashboard.weeklyMissions
            .where((m) => !m.isClaimed)
            .toList();
        final claimed = dashboard.weeklyMissions
            .where((m) => m.isClaimed)
            .toList();

        return [
          if (active.isEmpty)
            _buildWeekliesAllCompletedState(claimed.isNotEmpty)
          else
            ...active.map((m) => _buildMissionCard(m)),
          _buildCollapsibleCompletedSection(
            claimed,
            _weeklyClaimedExpanded,
            () => setState(
              () => _weeklyClaimedExpanded = !_weeklyClaimedExpanded,
            ),
          ),
        ];

      case _MissionTab.achievements:
        final active = dashboard.sideMissions
            .where((m) => !m.isClaimed)
            .toList();
        final claimed = dashboard.sideMissions
            .where((m) => m.isClaimed)
            .toList();

        return [
          if (active.isEmpty && claimed.isEmpty)
            _buildEmptyState()
          else if (active.isEmpty)
            _buildAchievementsAllCompletedState()
          else
            ...active.map((m) => _buildMissionCard(m)),
          _buildCollapsibleCompletedSection(
            claimed,
            _achievementsClaimedExpanded,
            () => setState(
              () =>
                  _achievementsClaimedExpanded = !_achievementsClaimedExpanded,
            ),
          ),
        ];
    }
  }

  Widget _buildMissionCard(
    PlayerMissionModel mission, {
    bool featured = false,
  }) {
    final accentColor = mission.claimable
        ? AppColors.green
        : mission.isClaimed
        ? AppColors.textMuted
        : AppColors.gold;

    final borderAccent = mission.claimable
        ? AppColors.green.withValues(alpha: 0.4)
        : featured
        ? AppColors.gold.withValues(alpha: 0.3)
        : AppColors.border.withValues(alpha: 0.5);

    final List<Widget> rewards = [];
    if (mission.reward.xp > 0) {
      rewards.add(
        _buildRewardItem(
          AppIcons.starBorderRounded,
          '+${mission.reward.xp} XP',
          AppColors.blue,
        ),
      );
    }
    if (mission.reward.cash > 0) {
      rewards.add(
        _buildRewardItem(
          AppIcons.paymentsOutlined,
          '+${_formatMoney(mission.reward.cash)} TL',
          AppColors.green,
        ),
      );
    }
    if (mission.reward.gold > 0) {
      rewards.add(
        _buildRewardItem(
          AppIcons.starRounded,
          '+${mission.reward.gold} Altın',
          AppColors.gold,
        ),
      );
    }

    final isLoading = _claimingMissionIds.contains(mission.id);
    final canClaim = mission.claimable && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: mission.isClaimed
            ? AppColors.cardBg.withValues(alpha: 0.5)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: borderAccent,
          width: (mission.claimable || featured) ? 1.2 : 1,
        ),
        boxShadow: [
          if (mission.claimable)
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  _iconForMission(mission.iconKey),
                  color: accentColor,
                  size: AppIconSizes.compact,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: AppTextStyles.body.standardCopyWith(
                        color: mission.isClaimed
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      mission.description,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.label,
                      ),
                    ),
                  ],
                ),
              ),
              if (mission.isClaimed)
                Icon(
                  AppIcons.checkCircleRounded,
                  color: AppColors.textMuted,
                  size: AppIconSizes.compact,
                )
              else if (!mission.claimable)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppFx.panelWash(0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${mission.progressCount}/${mission.targetCount}',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.caption,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (!mission.isClaimed) ...[
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: AppProgressBar(
                value: mission.progressRatio.clamp(0, 1),
                minHeight: 4.h,
                backgroundColor: AppFx.panelWash(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(spacing: 6.w, runSpacing: 4.h, children: rewards),
              ),
              if (mission.claimable || isLoading)
                SizedBox(
                  height: 26.h,
                  child: ElevatedButton(
                    onPressed: canClaim
                        ? () => _claimMissionReward(mission)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.textOnAccent,
                      disabledBackgroundColor: AppColors.green.withValues(
                        alpha: 0.35,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 10.w,
                            height: 10.h,
                            child: AppLoadingIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnAccent,
                            ),
                          )
                        : Text(
                            'Ödülü Al',
                            style: AppTextStyles.caption.standardCopyWith(
                              fontSize: AppTypography.label,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                )
              else if (mission.isClaimed)
                Text(
                  'Alındı',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleCompletedSection(
    List<PlayerMissionModel> claimedMissions,
    bool isExpanded,
    VoidCallback onToggle,
  ) {
    if (claimedMissions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tamamlanan Görevler (${claimedMissions.length})',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isExpanded
                      ? AppIcons.keyboardArrowUp
                      : AppIcons.keyboardArrowDown,
                  color: AppColors.textMuted,
                  size: AppIconSizes.compact,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          SizedBox(height: 4.h),
          ...claimedMissions.map((m) => _buildMissionCard(m)),
        ],
      ],
    );
  }

  Widget _buildRewardItem(IconData icon, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppIconSizes.xSmall),
          SizedBox(width: 4.w),
          Text(
            value,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.flagOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 14.h),
          Text(
            'Aktif Görev Bulunmadı',
            style: AppTextStyles.h2.standardCopyWith(
              fontSize: AppTypography.headline,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Yeni görevler oluştukça burada ilerleme paneli açılacak.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              fontSize: AppTypography.body,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildMainMissionEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.emojiEventsRounded,
              color: AppColors.gold,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 12.h),
            Text(
              'Tebrikler!',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Mevcut tüm ana hedefleri tamamladın.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailiesAllCompletedState(bool hasClaimedMissions) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.taskAltRounded,
              color: AppColors.green,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 12.h),
            Text(
              hasClaimedMissions ? 'Harika İş!' : 'Günlük Görev Yok',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              hasClaimedMissions
                  ? 'Bugünün tüm günlük görevlerini tamamladın.\nYarın yeni görevler gelecek!'
                  : 'Bugün için atanmış bir günlük görev bulunmuyor.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekliesAllCompletedState(bool hasClaimedMissions) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.taskAltRounded,
              color: AppColors.green,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 12.h),
            Text(
              hasClaimedMissions ? 'Harika İş!' : 'Haftalık Görev Yok',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              hasClaimedMissions
                  ? 'Bu haftanın tüm haftalık görevlerini tamamladın.\nGelecek hafta yeni görevler gelecek!'
                  : 'Bu hafta için atanmış bir haftalık görev bulunmuyor.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsAllCompletedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.emojiEventsRounded,
              color: AppColors.gold,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 12.h),
            Text(
              'Mükemmel!',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Tüm başarımları ve yan görevleri tamamladın.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) => Center(
    child: Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.errorOutline,
            color: AppColors.red,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 12.h),
          Text(
            'Görevler yüklenemedi',
            style: AppTextStyles.h2.standardCopyWith(
              fontSize: AppTypography.titleLarge,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: AppTextStyles.body.standardCopyWith(
              fontSize: AppTypography.bodySmall,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  IconData _iconForMission(String? iconKey) {
    switch (iconKey) {
      case 'store':
        return AppIcons.storefront;
      case 'warehouse':
        return AppIcons.warehouseRounded;
      case 'factory':
        return AppIcons.precisionManufacturing;
      case 'upgrade':
        return AppIcons.trendingUp;
      case 'sell':
        return AppIcons.pointOfSale;
      case 'transfer':
        return AppIcons.localShippingRounded;
      case 'research':
        return AppIcons.scienceRounded;
      default:
        return AppIcons.flagRounded;
    }
  }

  String _formatMoney(dynamic amount) {
    return AppMoney.compact(double.tryParse(amount.toString()) ?? 0);
  }

  Widget _buildDailyStreakCalendarCard() {
    final streakAsync = ref.watch(dailyStreakProvider);
    
    return streakAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (streak) {
        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.25),
              width: 1.w,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.gold,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Günlük Giriş Serisi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.body,
                    ),
                  ),
                  const Spacer(),
                  if (streak.streakCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '${streak.streakCount} Günlük Seri!',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 24.w) / 4;
                  return Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: List.generate(7, (index) {
                      final dayNum = index + 1;
                      final isClaimed = dayNum <= streak.streakCount;
                      final isToday = dayNum == streak.streakCount + 1 && streak.canClaimToday;
                      final isFuture = dayNum > streak.streakCount + (streak.canClaimToday ? 1 : 0);
                      
                      String rewardText = '';
                      IconData rewardIcon = Icons.monetization_on_rounded;
                      Color rewardColor = AppColors.green;
                      
                      switch (dayNum) {
                        case 1:
                          rewardText = '10K TL';
                          rewardIcon = Icons.payments_rounded;
                          rewardColor = AppColors.green;
                          break;
                        case 2:
                          rewardText = '25K TL';
                          rewardIcon = Icons.payments_rounded;
                          rewardColor = AppColors.green;
                          break;
                        case 3:
                          rewardText = '5 Altın';
                          rewardIcon = Icons.stars_rounded;
                          rewardColor = AppColors.gold;
                          break;
                        case 4:
                          rewardText = '50K TL';
                          rewardIcon = Icons.payments_rounded;
                          rewardColor = AppColors.green;
                          break;
                        case 5:
                          rewardText = '10 Altın';
                          rewardIcon = Icons.stars_rounded;
                          rewardColor = AppColors.gold;
                          break;
                        case 6:
                          rewardText = '100K TL';
                          rewardIcon = Icons.payments_rounded;
                          rewardColor = AppColors.green;
                          break;
                        case 7:
                          rewardText = '50 Altın';
                          rewardIcon = Icons.stars_rounded;
                          rewardColor = AppColors.gold;
                          break;
                      }

                      final width = dayNum == 7 ? (itemWidth * 2 + 8.w) : itemWidth;
                      
                      Widget cardContent = Container(
                        width: width,
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        decoration: BoxDecoration(
                          gradient: dayNum == 7
                              ? LinearGradient(
                                  colors: isClaimed
                                      ? [
                                          AppColors.cardBgLight.withValues(alpha: 0.3),
                                          AppColors.cardBgLight.withValues(alpha: 0.5),
                                        ]
                                      : [
                                          AppColors.gold.withValues(alpha: 0.15),
                                          AppColors.cardBgLight,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: dayNum == 7
                              ? null
                              : (isToday
                                  ? AppColors.gold.withValues(alpha: 0.08)
                                  : (isClaimed
                                      ? AppColors.cardBgLight.withValues(alpha: 0.3)
                                      : AppColors.cardBgLight)),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isToday
                                ? AppColors.gold
                                : (isClaimed
                                    ? AppColors.green.withValues(alpha: 0.5)
                                    : AppColors.borderGold.withValues(alpha: 0.15)),
                            width: isToday ? 1.5.w : 1.w,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$dayNum. Gün',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: isToday ? AppColors.gold : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.micro,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Icon(
                              isClaimed ? Icons.check_circle_rounded : (dayNum == 7 ? Icons.emoji_events_rounded : rewardIcon),
                              color: isClaimed ? AppColors.green : (isFuture ? AppColors.textMuted : rewardColor),
                              size: dayNum == 7 ? 22.sp : 18.sp,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              isClaimed ? 'Alındı' : rewardText,
                              style: AppTextStyles.caption.standardCopyWith(
                                color: isClaimed
                                    ? AppColors.green
                                    : (isToday ? AppColors.textPrimary : AppColors.textSecondary),
                                fontWeight: FontWeight.w800,
                                fontSize: AppTypography.micro,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isToday) {
                        return _PulsingGlowWrapper(child: cardContent);
                      }
                      return cardContent;
                    }),
                  );
                }
              ),
              
              SizedBox(height: 12.h),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: streak.canClaimToday
                      ? () async {
                          final success = await ref.read(dailyStreakProvider.notifier).claimReward();
                          if (success) {
                            AppHaptic.heavy();
                            if (!mounted) return;
                            
                            final nextDay = streak.streakCount + 1;
                            String rewardStr = '';
                            if (nextDay == 1) rewardStr = '10.000 TL';
                            if (nextDay == 2) rewardStr = '25.000 TL';
                            if (nextDay == 3) rewardStr = '5 Altın';
                            if (nextDay == 4) rewardStr = '50.000 TL';
                            if (nextDay == 5) rewardStr = '10 Altın';
                            if (nextDay == 6) rewardStr = '100.000 TL';
                            if (nextDay == 7) rewardStr = '50 Altın';

                            AppSnackbar.show(
                              context,
                              title: 'Giriş Ödülü Alındı!',
                              message: '$nextDay. Gün ödülü ($rewardStr) hesabınıza eklendi.',
                              type: SnackbarType.success,
                            );
                          } else {
                            if (!mounted) return;
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message: 'Giriş ödülü alınırken bir hata oluştu. Lütfen tekrar deneyin.',
                              type: SnackbarType.error,
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    disabledBackgroundColor: AppColors.cardBgLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  child: Text(
                    streak.canClaimToday ? 'GÜNLÜK ÖDÜLÜ AL' : 'Yarın Tekrar Gel!',
                    style: AppTextStyles.button.standardCopyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.bodySmall,
                      color: streak.canClaimToday ? AppColors.textOnAccent : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingGlowWrapper extends StatefulWidget {
  final Widget child;
  const _PulsingGlowWrapper({required this.child});

  @override
  State<_PulsingGlowWrapper> createState() => _PulsingGlowWrapperState();
}

class _PulsingGlowWrapperState extends State<_PulsingGlowWrapper> {
  bool _isLarge = true;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _isLarge ? 0.97 : 1.03,
        end: _isLarge ? 1.03 : 0.97,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {
        setState(() {
          _isLarge = !_isLarge;
        });
      },
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.15 * (scale - 0.97) / 0.06),
                  blurRadius: 8.r * (scale - 0.97) / 0.06,
                  spreadRadius: 1.r * (scale - 0.97) / 0.06,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

