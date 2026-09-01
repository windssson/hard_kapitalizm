import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';

class AppBottomNav extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _buildNavItem(context, ref, 0, AppIcons.home, 'Ana Sayfa'),
            _buildNavItem(context, ref, 1, AppIcons.chatBubbleRounded, 'Sohbet'),
            _buildNavItem(context, ref, 2, AppIcons.logistics, 'Lojistik'),
            _buildNavItem(context, ref, 3, AppIcons.storefront, 'Pazar'),
            _buildNavItem(context, ref, 4, AppIcons.person, 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
  ) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.gold : AppColors.textSecondary;
    final currentTutorialStep = ref.watch(tutorialProvider).step;

    GlobalKey? navKey;
    if (index == 3 && currentTutorialStep == TutorialStep.clickGoToMarket) {
      navKey = TutorialKeys.navMarketKey;
    } else if (index == 0 &&
        currentTutorialStep == TutorialStep.returnToHome) {
      navKey = TutorialKeys.navHomeKey;
    }

    return GestureDetector(
      key: navKey,
      onTap: () {
        if (index == 3 &&
            ref.read(tutorialProvider).step == TutorialStep.clickGoToMarket) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.selectMarketWarehouse);
        } else if (index == 0 &&
            ref.read(tutorialProvider).step == TutorialStep.returnToHome) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.returnToStoresModule);
        }

        if (index == selectedIndex) return;
        AppHaptic.light();
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
