import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_dashboard_model.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';

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
    ref.invalidate(playerProvider);
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
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(error.toString()),
                data: (dashboard) {
                  if (!dashboard.success || !dashboard.hasAnyMission) {
                    return _buildEmptyState();
                  }

                  if (_selectedTab == null) {
                    final hasActiveMain = dashboard.mainMission != null &&
                        !dashboard.mainMission!.isClaimed;
                    _selectedTab =
                        hasActiveMain ? _MissionTab.main : _MissionTab.daily;
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
              SizedBox(
                width: 44.w,
                height: 44.w,
                child: CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 4.w,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              Icon(
                dashboard.claimableCount > 0
                    ? Icons.card_giftcard_rounded
                    : Icons.emoji_events_rounded,
                color: dashboard.claimableCount > 0
                    ? AppColors.green
                    : AppColors.gold,
                size: 20.sp,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Toplam $completed / $total görev tamamlandı',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
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
                border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
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
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    '${dashboard.claimableCount} Ödül',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 10.sp,
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
    final achievementBadge =
        dashboard.sideMissions.where((m) => m.claimable).length;

    return Container(
      height: 42.h,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
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
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.gold : AppColors.textSecondary,
                        fontSize: 11.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      SizedBox(width: 5.w),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8.sp,
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
        final active = dashboard.dailyMissions.where((m) => !m.isClaimed).toList();
        final claimed = dashboard.dailyMissions.where((m) => m.isClaimed).toList();

        return [
          if (active.isEmpty)
            _buildDailiesAllCompletedState(claimed.isNotEmpty)
          else
            ...active.map((m) => _buildMissionCard(m)),
          _buildCollapsibleCompletedSection(
            claimed,
            _dailyClaimedExpanded,
            () => setState(() => _dailyClaimedExpanded = !_dailyClaimedExpanded),
          ),
        ];

      case _MissionTab.weekly:
        final active = dashboard.weeklyMissions.where((m) => !m.isClaimed).toList();
        final claimed = dashboard.weeklyMissions.where((m) => m.isClaimed).toList();

        return [
          if (active.isEmpty)
            _buildWeekliesAllCompletedState(claimed.isNotEmpty)
          else
            ...active.map((m) => _buildMissionCard(m)),
          _buildCollapsibleCompletedSection(
            claimed,
            _weeklyClaimedExpanded,
            () => setState(() => _weeklyClaimedExpanded = !_weeklyClaimedExpanded),
          ),
        ];

      case _MissionTab.achievements:
        final active = dashboard.sideMissions.where((m) => !m.isClaimed).toList();
        final claimed = dashboard.sideMissions.where((m) => m.isClaimed).toList();

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
                () => _achievementsClaimedExpanded = !_achievementsClaimedExpanded),
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
      rewards.add(_buildRewardItem(
          Icons.star_border_rounded, '+${mission.reward.xp} XP', AppColors.blue));
    }
    if (mission.reward.cash > 0) {
      rewards.add(_buildRewardItem(Icons.payments_outlined,
          '+${_formatMoney(mission.reward.cash)} TL', AppColors.green));
    }
    if (mission.reward.gold > 0) {
      rewards.add(_buildRewardItem(
          Icons.star_rounded, '+${mission.reward.gold} Altın', AppColors.gold));
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
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: TextStyle(
                        color: mission.isClaimed
                            ? AppColors.textMuted
                            : Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      mission.description,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              if (mission.isClaimed)
                Icon(Icons.check_circle_rounded,
                    color: AppColors.textMuted, size: 16.sp)
              else if (!mission.claimable)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${mission.progressCount}/${mission.targetCount}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9.sp,
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
              child: LinearProgressIndicator(
                value: mission.progressRatio.clamp(0, 1),
                minHeight: 4.h,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: rewards,
                ),
              ),
              if (mission.claimable || isLoading)
                SizedBox(
                  height: 26.h,
                  child: ElevatedButton(
                    onPressed:
                        canClaim ? () => _claimMissionReward(mission) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          AppColors.green.withValues(alpha: 0.35),
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
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Ödülü Al',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                )
              else if (mission.isClaimed)
                Text(
                  'Alındı',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
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
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                  size: 16.sp,
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
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 4.w),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
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
              Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 54.sp),
              SizedBox(height: 14.h),
              Text(
                'Aktif Görev Bulunmadı',
                style: AppTextStyles.h2.copyWith(fontSize: 17.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                'Yeni görevler oluştukça burada ilerleme paneli açılacak.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontSize: 12.sp),
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
            Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'Tebrikler!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Mevcut tüm ana hedefleri tamamladın.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
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
            Icon(Icons.task_alt_rounded, color: AppColors.green, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              hasClaimedMissions ? 'Harika İş!' : 'Günlük Görev Yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              hasClaimedMissions
                  ? 'Bugünün tüm günlük görevlerini tamamladın.\nYarın yeni görevler gelecek!'
                  : 'Bugün için atanmış bir günlük görev bulunmuyor.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
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
            Icon(Icons.task_alt_rounded, color: AppColors.green, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              hasClaimedMissions ? 'Harika İş!' : 'Haftalık Görev Yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              hasClaimedMissions
                  ? 'Bu haftanın tüm haftalık görevlerini tamamladın.\nGelecek hafta yeni görevler gelecek!'
                  : 'Bu hafta için atanmış bir haftalık görev bulunmuyor.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
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
            Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'Mükemmel!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Tüm başarımları ve yan görevleri tamamladın.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
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
              Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'Görevler yüklenemedi',
                style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  IconData _iconForMission(String? iconKey) {
    switch (iconKey) {
      case 'store':
        return Icons.storefront;
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'factory':
        return Icons.precision_manufacturing;
      case 'upgrade':
        return Icons.trending_up;
      case 'sell':
        return Icons.point_of_sale;
      case 'transfer':
        return Icons.local_shipping_rounded;
      case 'research':
        return Icons.science_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  String _formatMoney(dynamic amount) {
    final value = double.tryParse(amount.toString()) ?? 0;
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
