import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String currentRoute = GoRouterState.of(context).uri.toString();
    final bool isHome = currentRoute == '/home' || currentRoute == '/';
    
    final playerAsyncValue = ref.watch(playerStreamProvider);
    final player = playerAsyncValue.value;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1.w),
        ),
      ),
      child: Row(
        children: [
          if (!isHome) ...[
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
                child: Icon(Icons.arrow_back, color: AppColors.gold, size: 20.sp),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          // Logo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player != null ? player.playerName : '...',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: AppColors.goldDark, blurRadius: 4.r)],
                ),
              ),
              Text(
                player != null ? player.companyName : 'Winds Holdings',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  shadows: [Shadow(color: AppColors.goldDark, blurRadius: 2.r)],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Para Birimleri
          _buildCurrencyBadge(
            Icons.payments, 
            player != null ? _formatMoney(player.cash) : '...', 
            AppColors.green
          ),
          SizedBox(width: 6.w),
          _buildCurrencyBadge(
            Icons.star, 
            player != null ? player.gold.toString() : '...', 
            AppColors.goldLight
          ),
          SizedBox(width: 6.w),

          // Ayarlar
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderGoldLight.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(Icons.settings, color: AppColors.gold, size: 18.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyBadge(IconData icon, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 4.w),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 6.w),
          Icon(Icons.add, color: AppColors.gold, size: 14.sp),
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
