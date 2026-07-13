import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';

class ConstructionCountdownCard extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final DateTime finishAt;
  final Future<void> Function() onFinished;
  final Future<void> Function()? onReduceTimeWithAd;
  final IconData icon;

  const ConstructionCountdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.finishAt,
    required this.onFinished,
    this.onReduceTimeWithAd,
    this.icon = AppIcons.construction,
  });

  @override
  ConsumerState<ConstructionCountdownCard> createState() =>
      _ConstructionCountdownCardState();
}

class _ConstructionCountdownCardState
    extends ConsumerState<ConstructionCountdownCard> {
  bool _triggered = false;

  void _fireOnce() {
    if (_triggered) return;
    _triggered = true;
    Future.microtask(widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remaining = widget.finishAt.difference(now);
    if (remaining.inSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fireOnce();
      });
    }

    final safe = remaining.isNegative ? Duration.zero : remaining;
    final h = safe.inHours.toString().padLeft(2, '0');
    final m = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final s = (safe.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(AppColors.borderGold, 16.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(widget.icon, color: AppColors.gold, size: AppIconSizes.large),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTextStyles.h2),
                SizedBox(height: 4.h),
                Text(widget.subtitle, style: AppTextStyles.body),
                SizedBox(height: 8.h),
                Text(
                  safe.inSeconds <= 0 ? 'Tamamlaniyor...' : 'Kalan Sure: $h:$m:$s',
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (safe.inSeconds > 0 && widget.onReduceTimeWithAd != null) ...[
                  SizedBox(height: 10.h),
                  RewardedTimeReduceButton(
                    onPressed: () => widget.onReduceTimeWithAd!.call(),
                    label: 'Reklam izle -10 dk',
                    caption: 'Bir reklam odulu al ve insaat suresini 10 dakika kisalt.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
