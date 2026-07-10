import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.w),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, AppIcons.home, 'Ana Sayfa'),
            _buildNavItem(context, 1, AppIcons.chatBubbleRounded, 'Sohbet'),
            _buildNavItem(context, 2, AppIcons.map, 'Harita'),
            _buildNavItem(context, 3, AppIcons.storefront, 'Pazar'),
            _buildNavItem(context, 4, AppIcons.person, 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.gold : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        if (index == selectedIndex) return;
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/chat');
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
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 70.w,
        height: 60.h,
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.gold.withValues(alpha: 0.2), AppColors.navBg],
                ),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: AppIconSizes.large),
            SizedBox(height: 4.h),
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontSize: AppTypography.label,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
