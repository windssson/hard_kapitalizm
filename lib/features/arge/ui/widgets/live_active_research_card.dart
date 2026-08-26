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

    final targetColor = _getQualityColor(research.targetQuality);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131B2E),
            isDone ? const Color(0xFF0F2D24) : const Color(0xFF162444),
          ],
        ),
        border: Border.all(
          color: isDone
              ? AppColors.green.withValues(alpha: 0.8)
              : const Color(0xFF38BDF8).withValues(alpha: 0.4),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDone ? AppColors.green : const Color(0xFF38BDF8)).withValues(
              alpha: 0.15,
            ),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.green : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDone ? AppColors.green : const Color(0xFF38BDF8)).withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check_circle_outline_rounded : Icons.biotech_rounded,
                  color: isDone ? AppColors.green : const Color(0xFF38BDF8),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? AppColors.green : const Color(0xFF38BDF8),
                            boxShadow: [
                              BoxShadow(
                                color: isDone ? AppColors.green : const Color(0xFF38BDF8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          isDone ? 'GELİŞTİRME TAMAMLANDI' : 'ARAŞTIRMA SÜRÜYOR',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: isDone ? AppColors.green : const Color(0xFF38BDF8),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      research.productName,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _QualityTransitionBadge(
                current: research.currentQuality,
                target: research.targetQuality,
                targetColor: targetColor,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _ResearchProgressBar(
            research: research,
            progress: progress,
            isDone: isDone,
            targetColor: targetColor,
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.done_all_rounded : Icons.timer_outlined,
                      color: isDone ? AppColors.green : const Color(0xFF94A3B8),
                      size: 15.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isDone ? 'Kullanıma Hazır!' : _formatDuration(safeRemaining),
                      style: AppTextStyles.body.standardCopyWith(
                        color: isDone ? AppColors.green : AppColors.textPrimary,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isDone)
                ElevatedButton.icon(
                  onPressed: isUpgrading ? null : () => onCollect(research.id),
                  icon: Icon(Icons.download_done_rounded, size: 16.sp, color: AppColors.textOnAccent),
                  label: Text(
                    'ÖDÜLÜ AL',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textOnAccent,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 4,
                  ),
                ),
            ],
          ),
          if (!isDone && goldCost > 0) ...[
            SizedBox(height: 12.h),
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

  static Color _getQualityColor(int quality) {
    return switch (quality) {
      2 => const Color(0xFF10B981), // Emerald
      3 => const Color(0xFF38BDF8), // Cyan / Sapphire
      4 => const Color(0xFFA855F7), // Amethyst
      5 => const Color(0xFFF59E0B), // Radiant Gold
      _ => const Color(0xFF94A3B8), // Slate
    };
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
  final Color targetColor;

  const _ResearchProgressBar({
    required this.research,
    required this.progress,
    required this.isDone,
    required this.targetColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Geliştirme İlerlemesi',
              style: AppTextStyles.caption.standardCopyWith(
                color: const Color(0xFF94A3B8),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '%$pct',
              style: AppTextStyles.caption.standardCopyWith(
                color: isDone ? AppColors.green : const Color(0xFF38BDF8),
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8.h,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDone ? AppColors.green : const Color(0xFF38BDF8),
            ),
          ),
        ),
      ],
    );
  }
}

class _QualityTransitionBadge extends StatelessWidget {
  final int current;
  final int target;
  final Color targetColor;

  const _QualityTransitionBadge({
    required this.current,
    required this.target,
    required this.targetColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: targetColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: targetColor.withValues(alpha: 0.4), width: 1.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Q$current',
            style: AppTextStyles.caption.standardCopyWith(
              color: const Color(0xFF94A3B8),
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Icon(Icons.arrow_forward_rounded, color: targetColor, size: 12.sp),
          ),
          Text(
            'Q$target',
            style: AppTextStyles.caption.standardCopyWith(
              color: targetColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

