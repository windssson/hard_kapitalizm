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

enum _MissionFilter {
  all('Tum Gorevler'),
  claimable('Odul Hazir'),
  progress('Devam Eden'),
  completed('Tamamlanan');

  const _MissionFilter(this.label);
  final String label;
}

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  _MissionFilter _selectedFilter = _MissionFilter.all;
  final Set<String> _claimingMissionIds = <String>{};

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
          message: (result['message'] ?? 'Gorev odulu alinamadi.').toString(),
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
      if (gold > 0) rewardParts.add('+$gold Altin');
      if (xp > 0) rewardParts.add('+$xp XP');

      AppSnackbar.show(
        context,
        title: 'Gorev Tamamlandi',
        message: rewardParts.isEmpty
            ? 'Odul basariyla alindi.'
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
            const SecondaryTopBar(title: 'Gorevler'),
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

                  final filtered = _applyFilter(dashboard.allMissions);
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                      children: [
                        _buildOverviewCard(dashboard),
                        SizedBox(height: 14.h),
                        _buildFilterBar(),
                        SizedBox(height: 14.h),
                        if (dashboard.mainMission != null &&
                            _selectedFilter == _MissionFilter.all) ...[
                          _buildSectionTitle(
                            'Ana Gorev',
                            'Oyunun sonraki hedefi burada.',
                          ),
                          SizedBox(height: 8.h),
                          _buildMissionCard(
                            dashboard.mainMission!,
                            featured: true,
                          ),
                          SizedBox(height: 14.h),
                        ],
                        if (dashboard.dailyMissions.isNotEmpty &&
                            _selectedFilter == _MissionFilter.all) ...[
                          _buildSectionTitle(
                            'Gunluk Gorevler',
                            dashboard.dailyClaimableCount > 0
                                ? '${dashboard.dailyClaimableCount} odul hazir'
                                : '${dashboard.dailyCompletedCount}/${dashboard.dailyMissions.length} tamamlandi',
                          ),
                          SizedBox(height: 8.h),
                          ...dashboard.dailyMissions.map(
                            (mission) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _buildMissionCard(mission),
                            ),
                          ),
                          SizedBox(height: 6.h),
                        ],
                        _buildSectionTitle(
                          _sectionTitleForFilter(filtered.length),
                          '${filtered.length} gorev goruntuleniyor',
                        ),
                        SizedBox(height: 8.h),
                        if (filtered.isEmpty)
                          _buildFilterEmptyState()
                        else
                          ...filtered.map(
                            (mission) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _buildMissionCard(mission),
                            ),
                          ),
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

  Widget _buildOverviewCard(PlayerMissionDashboardModel dashboard) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.gold, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Gorev Merkezi',
                style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
              ),
              const Spacer(),
              _buildOverviewBadge(
                dashboard.claimableCount > 0
                    ? '${dashboard.claimableCount} Hazir'
                    : '${dashboard.completedCount}/${dashboard.totalCount}',
                dashboard.claimableCount > 0
                    ? AppColors.green
                    : AppColors.blue,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Ana gorevler seni oyunda yonlendirir. Yan gorevler ve basarilar ise ilerleme hizini destekler.',
            style: AppTextStyles.body.copyWith(fontSize: 11.sp),
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: dashboard.completionRatio,
              minHeight: 10.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildMiniStat(
                'Hazir',
                '${dashboard.claimableCount}',
                AppColors.green,
              ),
              SizedBox(width: 8.w),
              _buildMiniStat(
                'Gunluk',
                '${dashboard.dailyClaimableCount}',
                Colors.orange,
              ),
              SizedBox(width: 8.w),
              _buildMiniStat(
                'Devam Eden',
                '${dashboard.inProgressCount}',
                AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: AppTextStyles.body.copyWith(fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _MissionFilter.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final filter = _MissionFilter.values[index];
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.14)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissionCard(
    PlayerMissionModel mission, {
    bool featured = false,
  }) {
    final missionTypeColor = _missionTypeColor(mission);
    final isLoading = _claimingMissionIds.contains(mission.id);
    final canClaim = mission.claimable && !isLoading;
    final accentColor = mission.claimable
        ? AppColors.green
        : mission.isClaimed
            ? AppColors.blue
            : AppColors.gold;

    return Container(
      padding: EdgeInsets.all(featured ? 16.w : 14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(featured ? 18.r : 16.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForMission(mission.iconKey),
                  color: accentColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: missionTypeColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(
                              color: missionTypeColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            mission.missionTypeLabel,
                            style: TextStyle(
                              color: missionTypeColor,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mission.title,
                            style: AppTextStyles.body.copyWith(
                              fontSize: featured ? 14.sp : 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _eventHintLabel(mission.eventKey),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(mission, isLoading),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            mission.description,
            style: AppTextStyles.body.copyWith(fontSize: 11.sp),
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: mission.progressRatio.clamp(0, 1),
              minHeight: 8.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildInfoChip(
                      _missionProgressLabel(mission),
                      AppColors.textMuted,
                    ),
                    _buildInfoChip(
                      mission.compactRewardText,
                      AppColors.goldLight,
                    ),
                  ],
                ),
              ),
              if (mission.claimable || isLoading)
                SizedBox(
                  height: 34.h,
                  child: ElevatedButton(
                    onPressed: canClaim ? () => _claimMissionReward(mission) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.green.withValues(alpha: 0.35),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 14.w,
                            height: 14.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Odulu Al',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
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

  Widget _buildStatusPill(PlayerMissionModel mission, bool isLoading) {
    final color = mission.claimable
        ? AppColors.green
        : mission.isClaimed
            ? AppColors.blue
            : AppColors.gold;
    final text = isLoading
        ? 'Aliniyor'
        : mission.claimable
            ? 'Hazir'
            : mission.isClaimed
                ? 'Tamam'
                : '${mission.progressCount}/${mission.targetCount}';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _missionProgressLabel(PlayerMissionModel mission) {
    if (mission.claimable) return 'Odul Hazir';
    if (mission.isClaimed) return 'Tamamlandi';
    return '${mission.progressCount}/${mission.targetCount}';
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
            'Aktif gorev bulunamadi',
            style: AppTextStyles.h2.copyWith(fontSize: 17.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Yeni gorevler olustukca burada ilerleme paneli acilacak.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 12.sp),
          ),
        ],
      ),
    ),
  );

  Widget _buildFilterEmptyState() => Container(
    padding: EdgeInsets.all(18.w),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      'Bu filtre icin gorev bulunamadi.',
      style: AppTextStyles.body.copyWith(fontSize: 12.sp),
      textAlign: TextAlign.center,
    ),
  );

  Widget _buildErrorState(String message) => Center(
    child: Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.red, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'Gorevler yuklenemedi',
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

  List<PlayerMissionModel> _applyFilter(List<PlayerMissionModel> missions) {
    switch (_selectedFilter) {
      case _MissionFilter.all:
        return missions;
      case _MissionFilter.claimable:
        return missions.where((mission) => mission.claimable).toList();
      case _MissionFilter.progress:
        return missions.where((mission) => mission.isInProgress).toList();
      case _MissionFilter.completed:
        return missions
            .where((mission) => mission.isCompleted || mission.isClaimed)
            .toList();
    }
  }

  String _sectionTitleForFilter(int count) {
    switch (_selectedFilter) {
      case _MissionFilter.all:
        return 'Tum Gorevler';
      case _MissionFilter.claimable:
        return 'Odulu Hazir Gorevler';
      case _MissionFilter.progress:
        return 'Devam Eden Gorevler';
      case _MissionFilter.completed:
        return 'Tamamlanan Gorevler';
    }
  }

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

  Color _missionTypeColor(PlayerMissionModel mission) {
    switch (mission.missionType) {
      case 'main':
        return AppColors.gold;
      case 'daily':
        return Colors.orangeAccent;
      case 'achievement':
        return Colors.purpleAccent;
      case 'side':
      default:
        return AppColors.blue;
    }
  }

  String _eventHintLabel(String eventKey) {
    if (eventKey.contains('construction')) return 'Insaat ilerlemesi';
    if (eventKey.contains('upgrade')) return 'Yukseltme ilerlemesi';
    if (eventKey.contains('sale')) return 'Satis ilerlemesi';
    if (eventKey.contains('transfer')) return 'Transfer ilerlemesi';
    if (eventKey.contains('research')) return 'Arastirma ilerlemesi';
    return 'Genel ilerleme';
  }

  String _formatMoney(dynamic amount) {
    final value = double.tryParse(amount.toString()) ?? 0;
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
