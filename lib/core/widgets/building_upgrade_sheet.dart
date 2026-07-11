import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class BuildingUpgradeBenefit {
  const BuildingUpgradeBenefit({
    required this.icon,
    required this.label,
    required this.before,
    required this.after,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String before;
  final String after;
  final Color? accentColor;
}

Future<void> showBuildingUpgradeSheet({
  required BuildContext context,
  required String title,
  required String buildingName,
  required IconData icon,
  required int currentLevel,
  required int targetLevel,
  required String durationLabel,
  required String costLabel,
  required List<BuildingUpgradeBenefit> benefits,
  required Future<void> Function() onConfirm,
  String? requirementLabel,
  bool canConfirm = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: AppFx.scrim(0.72),
    builder: (sheetContext) => _BuildingUpgradeSheet(
      title: title,
      buildingName: buildingName,
      icon: icon,
      currentLevel: currentLevel,
      targetLevel: targetLevel,
      durationLabel: durationLabel,
      costLabel: costLabel,
      benefits: benefits,
      requirementLabel: requirementLabel,
      canConfirm: canConfirm,
      onConfirm: () async {
        Navigator.of(sheetContext).pop();
        await onConfirm();
      },
    ),
  );
}

class _BuildingUpgradeSheet extends StatelessWidget {
  const _BuildingUpgradeSheet({
    required this.title,
    required this.buildingName,
    required this.icon,
    required this.currentLevel,
    required this.targetLevel,
    required this.durationLabel,
    required this.costLabel,
    required this.benefits,
    required this.requirementLabel,
    required this.canConfirm,
    required this.onConfirm,
  });

  final String title;
  final String buildingName;
  final IconData icon;
  final int currentLevel;
  final int targetLevel;
  final String durationLabel;
  final String costLabel;
  final List<BuildingUpgradeBenefit> benefits;
  final String? requirementLabel;
  final bool canConfirm;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border(
          top: BorderSide(color: AppColors.borderGold, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.55),
            blurRadius: 32.r,
            offset: Offset(0, -10.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70.h,
            right: -55.w,
            child: Container(
              width: 190.w,
              height: 190.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 20.h + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                _Header(title: title, buildingName: buildingName, icon: icon),
                SizedBox(height: 18.h),
                _LevelRoute(
                  currentLevel: currentLevel,
                  targetLevel: targetLevel,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        icon: AppIcons.schedule,
                        label: 'TAMAMLANMA',
                        value: durationLabel,
                        accentColor: AppColors.gold,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _SummaryTile(
                        icon: AppIcons.paymentsRounded,
                        label: 'YATIRIM',
                        value: costLabel,
                        accentColor: AppColors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Text(
                  'YUKSELTME KAZANIMLARI',
                  style: AppTextStyles.overline.standardCopyWith(
                    color: AppColors.gold,
                  ),
                ),
                SizedBox(height: 8.h),
                ...benefits.map(
                  (benefit) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _BenefitTile(benefit: benefit),
                  ),
                ),
                if (requirementLabel != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppFx.goldWash(0.07),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.borderGoldLight),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.lockRounded,
                          color: AppColors.gold,
                          size: AppIconSizes.small,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            requirementLabel!,
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canConfirm ? onConfirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                      disabledBackgroundColor: AppColors.cardBgLight,
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.upgradeRounded,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 9.w),
                        Text(
                          canConfirm
                              ? 'YUKSELTMEYI BASLAT'
                              : 'GEREKSINIM KARSILANMIYOR',
                          style: AppTextStyles.button.standardCopyWith(
                            fontSize: AppTypography.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.buildingName,
    required this.icon,
  });

  final String title;
  final String buildingName;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: AppFx.goldWash(0.14),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Icon(icon, color: AppColors.gold, size: AppIconSizes.hero),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                buildingName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelRoute extends StatelessWidget {
  const _LevelRoute({required this.currentLevel, required this.targetLevel});

  final int currentLevel;
  final int targetLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBg, AppColors.cardBgLight],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGoldLight),
      ),
      child: Row(
        children: [
          _LevelBadge(label: 'MEVCUT', level: currentLevel, highlighted: false),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                children: [
                  Expanded(child: Divider(color: AppColors.borderGoldLight)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7.w),
                    child: Icon(
                      AppIcons.arrowForwardRounded,
                      color: AppColors.gold,
                      size: AppIconSizes.small,
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.gold)),
                ],
              ),
            ),
          ),
          _LevelBadge(label: 'HEDEF', level: targetLevel, highlighted: true),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.label,
    required this.level,
    required this.highlighted,
  });

  final String label;
  final int level;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.overline.standardCopyWith(
            color: highlighted ? AppColors.gold : AppColors.textMuted,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          'LV.$level',
          style: AppTextStyles.h2.standardCopyWith(
            color: highlighted ? AppColors.gold : AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: AppIconSizes.regular),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.overline),
                SizedBox(height: 2.h),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.benefit});

  final BuildingUpgradeBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final accent = benefit.accentColor ?? AppColors.green;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(benefit.icon, color: accent, size: AppIconSizes.small),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              benefit.label,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            benefit.before,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 7.w),
            child: Icon(
              AppIcons.arrowForwardRounded,
              color: accent,
              size: AppIconSizes.xSmall,
            ),
          ),
          Text(
            benefit.after,
            style: AppTextStyles.title.standardCopyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
