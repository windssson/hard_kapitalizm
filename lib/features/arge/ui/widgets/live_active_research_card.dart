import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';

class LiveActiveResearchCard extends ConsumerWidget {
  final ArgeResearchModel research;
  final bool isUpgrading;
  final Future<void> Function(String researchId) onCollect;
  final Future<void> Function(String researchId, int goldCost) onFinishWithGold;

  const LiveActiveResearchCard({
    super.key,
    required this.research,
    required this.isUpgrading,
    required this.onCollect,
    required this.onFinishWithGold,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remaining = research.finishAt.toLocal().difference(now);
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final isDone = !research.finishAt.isAfter(now.toUtc());
    final totalDuration = research.finishAt.difference(research.startedAt);
    final elapsed = now.toUtc().difference(research.startedAt);
    final progress = totalDuration.inSeconds <= 0
        ? 1.0
        : (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
    final goldCost = _goldCostToFinish(safeRemaining);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A1A3A),
            AppColors.cardBgLight.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(
          color: isDone
              ? AppColors.green.withValues(alpha: 0.7)
              : AppColors.blue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? AppColors.green : AppColors.blue)
                .withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.science, color: AppColors.blue, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arastirma Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      research.productName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _QualityBadge(
                current: research.currentQuality,
                target: research.targetQuality,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _ResearchProgressBar(
            research: research,
            progress: progress,
            isDone: isDone,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.access_time,
                color: isDone ? AppColors.green : AppColors.textSecondary,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                isDone ? 'Tamamlandi! Alabilirsin.' : _formatDuration(safeRemaining),
                style: TextStyle(
                  color: isDone ? AppColors.green : AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isDone)
                _ActionPill(
                  label: 'TOPLA',
                  icon: Icons.download_done,
                  color: AppColors.green,
                  onTap: () => onCollect(research.id),
                ),
            ],
          ),
          if (!isDone && goldCost > 0) ...[
            SizedBox(height: 10.h),
            GoldFinishButton(
              starCost: goldCost,
              onPressed: isUpgrading
                  ? null
                  : () => onFinishWithGold(research.id, goldCost),
            ),
          ],
        ],
      ),
    );
  }

  static int _goldCostToFinish(Duration remaining) {
    final mins = remaining.inMinutes;
    if (mins <= 0) return 0;
    return ((mins / 30).ceil()).clamp(1, 999999);
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _ResearchProgressBar extends StatelessWidget {
  final ArgeResearchModel research;
  final double progress;
  final bool isDone;

  const _ResearchProgressBar({
    required this.research,
    required this.progress,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kalite ${research.currentQuality} -> ${research.targetQuality}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: isDone ? AppColors.green : AppColors.blue,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(
          height: 8.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.r),
                gradient: LinearGradient(
                  colors: isDone
                      ? [AppColors.green.withValues(alpha: 0.7), AppColors.green]
                      : [AppColors.blue.withValues(alpha: 0.7), AppColors.blue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDone ? AppColors.green : AppColors.blue)
                        .withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final int current;
  final int target;

  const _QualityBadge({
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$current -> $target',
        style: TextStyle(
          color: AppColors.goldLight,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
