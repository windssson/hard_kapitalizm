import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class SecondaryTopBar extends ConsumerWidget {
  final String? title;
  final bool showStats;

  const SecondaryTopBar({super.key, this.title, this.showStats = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsyncValue = ref.watch(playerProvider);
    final player = playerAsyncValue.value;

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
                // Back Button
                GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.gold,
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),

                // Title or Player Info
                Expanded(
                  child: title != null
                      ? Text(
                          title!.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              player != null ? player.playerName : '...',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              player != null ? player.companyName : '...',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),

                // Right side stats
                if (showStats) ...[
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
                ],
              ],
            ),
          ),
        ),
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

  String _formatMoney(dynamic amount) {
    if (amount == null) return '0';
    double val = double.parse(amount.toString());
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }
}
