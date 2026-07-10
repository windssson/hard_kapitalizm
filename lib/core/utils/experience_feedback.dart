import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Seviye Atladi!',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tebrikler, sirket seviyen yukseldi.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
            SizedBox(height: 12.h),
            _buildFeedbackRow('Eski Seviye', experience.oldLevel.toString()),
            _buildFeedbackRow(
              'Yeni Seviye',
              experience.newLevel.toString(),
              valueColor: AppColors.gold,
            ),
            _buildFeedbackRow(
              'Kazanilan XP',
              '+${experience.amount}',
              valueColor: AppColors.blue,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Harika'),
          ),
        ],
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

Widget _buildFeedbackRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
        ),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
