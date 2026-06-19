import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';

class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider).value;
    final missionDashboard = ref.watch(playerMissionDashboardProvider).value;
    final claimableMissionCount = missionDashboard?.claimableCount ?? 0;
    final progress = (player?.expProgressRatio ?? 0).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.fromLTRB(6.w, 8.h, 6.w, 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.55),
          width: 1.1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14.r,
            offset: Offset(0, 6.h),
          ),
          BoxShadow(
            color: AppColors.goldDark.withValues(alpha: 0.16),
            blurRadius: 8.r,
            spreadRadius: 0.5.r,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF02060D).withValues(alpha: 0.92),
            image: const DecorationImage(
              image: AssetImage('assets/theme/cartback.webp'),
              fit: BoxFit.fill,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF06101B).withValues(alpha: 0.38),
                const Color(0xFF02060D).withValues(alpha: 0.54),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380.w;
              return Padding(
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: compact ? 55 : 57,
                      child: _buildProfilePanel(
                        context: context,
                        player: player,
                        progress: progress,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: compact ? 4.w : 6.w),
                    Expanded(
                      flex: compact ? 27 : 28,
                      child: _buildResourceColumn(
                        context,
                        player,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: compact ? 4.w : 6.w),
                    _buildNotificationAction(
                      context: context,
                      claimableMissionCount: claimableMissionCount,
                      compact: compact,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePanel({
    required BuildContext context,
    required dynamic player,
    required double progress,
    required bool compact,
  }) {
    return Row(
      children: [
        _buildAvatarMedallion(player, compact: compact),
        SizedBox(width: compact ? 6.w : 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player?.companyName ?? 'Yeni Holding',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 14.sp : 16.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                player?.playerName ?? 'CEO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 9.sp : 10.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 4.h : 5.h),
              FractionallySizedBox(
                widthFactor: compact ? 0.82 : 0.86,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: compact ? 8.h : 9.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: AppColors.borderGold.withValues(alpha: 0.75),
                      width: 1.w,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999.r),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.goldDark,
                                AppColors.gold,
                                AppColors.goldLight,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 8.r,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 3.h : 4.h),
              Text(
                '${player?.currentLevelExperience ?? 0} / ${player?.nextLevelRequiredExperience ?? 1} XP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.94),
                  fontSize: compact ? 7.sp : 7.8.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarMedallion(dynamic player, {required bool compact}) {
    final avatarSize = compact ? 52.w : 60.w;
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.goldDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 16.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            padding: EdgeInsets.all(3.w),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBg,
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.55),
                  width: 1.w,
                ),
              ),
              child: ClipOval(
                child: CachedAssetImage(
                  fileName: player?.avatarId ?? 'avatar_1.webp',
                  fit: BoxFit.cover,
                  placeholder: Icon(
                    Icons.person,
                    color: AppColors.gold,
                    size: compact ? 20.sp : 24.sp,
                  ),
                  errorWidget: Icon(
                    Icons.person,
                    color: AppColors.gold,
                    size: compact ? 20.sp : 24.sp,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -1.w,
            bottom: 2.h,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6.w : 7.w,
                vertical: compact ? 4.h : 4.5.h,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF3F2D09), AppColors.goldDark],
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: 0.8),
                ),
              ),
              child: Text(
                '${player?.level ?? 1}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 8.sp : 9.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceColumn(
    BuildContext context,
    dynamic player, {
    required bool compact,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildResourceCard(
          context: context,
          icon: Icons.payments_rounded,
          iconColor: AppColors.green,
          value: _formatMoney(player?.cash ?? 0),
          actionIcon: Icons.history_rounded,
          actionColor: AppColors.green,
          onTap: () => context.push('/cash-history'),
          compact: compact,
        ),
        SizedBox(height: compact ? 4.h : 5.h),
        _buildResourceCard(
          context: context,
          icon: Icons.star_rounded,
          iconColor: AppColors.gold,
          value: (player?.gold ?? 0).toStringAsFixed(0),
          actionIcon: Icons.add_rounded,
          actionColor: AppColors.goldLight,
          onTap: () => context.push('/profile'),
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required IconData actionIcon,
    required Color actionColor,
    required VoidCallback onTap,
    required bool compact,
  }) {
    return Container(
      height: compact ? 26.h : 29.h,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5.w : 6.w,
        vertical: compact ? 3.h : 4.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.9),
            AppColors.cardBgLight.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.95)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 18.w : 20.w,
            height: compact ? 18.w : 20.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: compact ? 11.5.sp : 12.5.sp,
            ),
          ),
          SizedBox(width: compact ? 4.w : 5.w),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: compact ? 10.2.sp : 11.4.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: compact ? 3.w : 4.w),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: compact ? 15.w : 17.w,
              height: compact ? 15.w : 17.w,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                actionIcon,
                color: actionColor,
                size: compact ? 10.sp : 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationAction({
    required BuildContext context,
    required int claimableMissionCount,
    required bool compact,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => context.push('/missions'),
          borderRadius: BorderRadius.circular(compact ? 12.r : 14.r),
          child: Container(
            width: compact ? 38.w : 42.w,
            height: compact ? 50.h : 56.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.cardBg.withValues(alpha: 0.92),
                  AppColors.navBg.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(compact ? 12.r : 14.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldDark.withValues(alpha: 0.12),
                  blurRadius: 12.r,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.goldLight,
                  size: compact ? 18.sp : 20.sp,
                ),
                if (!compact) ...[
                  SizedBox(height: 2.h),
                  Text(
                    'Gorev',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 6.8.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (claimableMissionCount > 0)
          Positioned(
            right: -3.w,
            top: -5.h,
            child: Container(
              constraints: BoxConstraints(
                minWidth: compact ? 18.w : 20.w,
                minHeight: compact ? 18.w : 20.w,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4.w : 5.w,
                vertical: 2.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 1.2.w),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.3),
                    blurRadius: 8.r,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                claimableMissionCount > 99
                    ? '99+'
                    : claimableMissionCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 7.5.sp : 8.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '0';
    final val = double.parse(amount.toString());
    if (val >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(1)}B';
    }
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }
}
