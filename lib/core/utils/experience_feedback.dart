import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
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
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tebrikler, sirket seviyen yukseldi.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
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

  AppSnackbar.show(
    context,
    title: 'XP Kazanildi',
    message: '+${experience.amount} XP',
    type: SnackbarType.success,
  );
}

Widget _buildFeedbackRow(
  String label,
  String value, {
  Color? valueColor,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
