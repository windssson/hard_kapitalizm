import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/features/auth/models/experience_gain_model.dart';

Future<void> showExperienceFeedbackFromResult(
  BuildContext context,
  Map<String, dynamic> result,
) async {
  final rawExperience = result['experience'];
  if (rawExperience is! Map) return;

  final experience = ExperienceGainModel.fromJson(
    Map<String, dynamic>.from(rawExperience),
  );

  if (experience.amount <= 0) return;

  if (experience.leveledUp) {
    AppHaptic.heavy();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CelebrationLevelUpDialog(
        experience: experience,
      ),
    );
    return;
  }

  FloatingFeedback.show(
    context,
    amount: experience.amount.toDouble(),
    type: FloatingFeedbackType.xp,
  );
}

class _CelebrationLevelUpDialog extends StatefulWidget {
  final ExperienceGainModel experience;

  const _CelebrationLevelUpDialog({required this.experience});

  @override
  State<_CelebrationLevelUpDialog> createState() =>
      _CelebrationLevelUpDialogState();
}

class _CelebrationLevelUpDialogState extends State<_CelebrationLevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experience;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Ana Kart Gövdesi
            Container(
              margin: EdgeInsets.only(top: 45.h),
              padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 20.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cardBg,
                    AppColors.cardBgLight.withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: AppColors.borderGold,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tebrik Başlığı
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.goldLight,
                        AppColors.gold,
                        AppColors.warning,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'SEVİYE ATLADIN!',
                      style: AppTextStyles.h1.standardCopyWith(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Şirketinizin ticari gücü ve piyasa itibarı yükseldi.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.bodySmall,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),

                  // Seviye Geçiş Paneli (Eski ➔ Yeni)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.borderGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Eski Seviye
                        Column(
                          children: [
                            Text(
                              'Önceki',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.micro,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Lv. ${exp.oldLevel}',
                              style: AppTextStyles.title.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontSize: AppTypography.headline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // Ok Simgesi
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.gold,
                            size: 20.sp,
                          ),
                        ),

                        // Yeni Seviye
                        Column(
                          children: [
                            Text(
                              'YENİ SEVİYE',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: AppTypography.micro,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Lv. ${exp.newLevel}',
                              style: AppTextStyles.h1.standardCopyWith(
                                color: AppColors.goldLight,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Kazanılan Ayrıcalıklar / Bilgi
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      children: [
                        _buildPerkRow(
                          Icons.insights_rounded,
                          'Kazanılan Deneyim',
                          '+${exp.amount} XP',
                          AppColors.blue,
                        ),
                        Divider(
                          color: AppColors.border.withValues(alpha: 0.3),
                          height: 12.h,
                        ),
                        _buildPerkRow(
                          Icons.lock_open_rounded,
                          'Yeni Kilitler',
                          'Yeni binalar ve pazar fırsatları açıldı',
                          AppColors.green,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 22.h),

                  // Devam Et Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed: () {
                        AppHaptic.medium();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.textOnAccent,
                        elevation: 4,
                        shadowColor: AppColors.gold.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'KAPİTALİZMİ FETHET',
                        style: AppTextStyles.button.standardCopyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontSize: AppTypography.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Üstte Parlayan Taç / Rozet İkonu
            Positioned(
              top: 0,
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 86.w,
                    height: 86.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.goldLight,
                          AppColors.gold,
                          AppColors.goldDark,
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(
                            alpha: 0.4 * _glowAnimation.value,
                          ),
                          blurRadius: 20 * _glowAnimation.value,
                          spreadRadius: 4 * _glowAnimation.value,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.textOnAccent,
                        size: 46.sp,
                      ),
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

  Widget _buildPerkRow(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: AppIconSizes.small),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.label,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
