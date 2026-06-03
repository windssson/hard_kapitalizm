import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';

class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsyncValue = ref.watch(playerProvider);
    final missionDashboard = ref.watch(playerMissionDashboardProvider).value;
    final notificationDashboard = ref.watch(
      playerNotificationDashboardProvider,
    ).value;
    final player = playerAsyncValue.value;
    final claimableMissionCount = missionDashboard?.claimableCount ?? 0;
    final unreadNotificationCount = notificationDashboard?.unreadCount ?? 0;
    final progress = player?.expProgressRatio ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10.r,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.cardBg.withValues(alpha: 0.85),
                  AppColors.navBg.withValues(alpha: 0.9),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderGold.withValues(alpha: 0.4),
                  width: 1.5.h,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLevelCircle(player?.level ?? 1, progress),
                const Spacer(),
                Row(
                  children: [
                    _buildCompactCurrency(
                      Icons.payments_rounded,
                      _formatMoney(player?.cash ?? 0),
                      AppColors.green,
                    ),
                    SizedBox(width: 6.w),
                    _buildCompactCurrency(
                      Icons.star_rounded,
                      player?.gold.toInt().toString() ?? '0',
                      AppColors.goldLight,
                    ),
                    SizedBox(width: 10.w),
                    Row(
                      children: [
                        _buildActionIcon(
                          icon: Icons.notifications_none_rounded,
                          badgeCount: unreadNotificationCount,
                          onTap: () => context.push('/notifications'),
                        ),
                        SizedBox(width: 8.w),
                        _buildActionIcon(
                          icon: Icons.flag_outlined,
                          badgeCount: claimableMissionCount,
                          onTap: () => context.push('/missions'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCircle(int level, double progress) {
    return SizedBox(
      width: 44.r,
      height: 44.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44.r,
            height: 44.r,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 2.5.w,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.background.withValues(alpha: 0.5),
              ),
            ),
          ),
          SizedBox(
            width: 44.r,
            height: 44.r,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              strokeWidth: 2.5.w,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 4.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LV',
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                Text(
                  level.toString(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCurrency(IconData icon, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(width: 4.w),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4.w,
            top: -4.h,
            child: Container(
              constraints: BoxConstraints(
                minWidth: 16.w,
                minHeight: 16.h,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 2.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: AppColors.background,
                  width: 1.w,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w800,
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
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }
}
