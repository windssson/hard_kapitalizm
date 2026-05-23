import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class ConstructionCountdownCard extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final DateTime finishAt;
  final Future<void> Function() onFinished;
  final IconData icon;

  const ConstructionCountdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.finishAt,
    required this.onFinished,
    this.icon = Icons.construction,
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
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold),
      ),
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
            child: Icon(widget.icon, color: AppColors.gold, size: 24.sp),
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
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
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
