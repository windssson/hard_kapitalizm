import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class SecondaryTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const SecondaryTopBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider).value;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: AppDecorations.secondaryTopBar(0),
          child: Row(
            children: [
              // Back Button
              Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap:
                      onBackPressed ??
                      () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                  borderRadius: BorderRadius.circular(999.r),
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: AppDecorations.badge(
                      bgColor: AppColors.cardBg,
                      borderColor: AppColors.borderGoldLight.withValues(
                        alpha: 0.3,
                      ),
                      isCircle: true,
                    ),
                    child: Icon(
                      AppIcons.arrowBackIosNewRounded,
                      color: AppColors.gold,
                      size: AppIconSizes.compact,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Title
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Player Wealth Display
              if (player != null) ...[
                _buildCompactCurrencyBox(
                  icon: AppIcons.paymentsRounded,
                  value: AppMoney.compact(player.cash),
                  color: AppColors.green,
                ),
                SizedBox(width: 6.w),
                _buildCompactCurrencyBox(
                  icon: AppIcons.starRounded,
                  value: player.gold.toStringAsFixed(0),
                  color: AppColors.gold,
                ),
              ],
              if (actions != null) ...[SizedBox(width: 8.w), ...actions!],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCurrencyBox({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: AppDecorations.badge(
        bgColor: AppColors.background.withValues(alpha: 0.4),
        borderColor: color.withValues(alpha: 0.15),
        radius: 12.r,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppIconSizes.xSmall),
          SizedBox(width: 4.w),
          Text(
            value,
            style: AppTextStyles.label.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(58.h);
}
