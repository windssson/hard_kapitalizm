import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

class StoreQuickActions extends StatelessWidget {
  final bool canOpenNewSlot;
  final VoidCallback onUpgradeTap;
  final VoidCallback onBoostTap;
  final VoidCallback onReportTap;
  final VoidCallback? onBulkPricingTap;
  final VoidCallback? onOpenSlotTap;
  final Key? openSlotKey;

  const StoreQuickActions({
    super.key,
    required this.canOpenNewSlot,
    required this.onUpgradeTap,
    required this.onBoostTap,
    required this.onReportTap,
    this.onBulkPricingTap,
    required this.onOpenSlotTap,
    this.openSlotKey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = onBulkPricingTap != null ? 5 : 4;
        final itemWidth = ((constraints.maxWidth - ((count - 1) * 8.w)) / count).clamp(
          58.w,
          85.w,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.upgradeRounded,
              label: 'Yükselt',
              color: AppColors.green,
              onTap: onUpgradeTap,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.flashOnRounded,
              label: 'Boost',
              color: AppColors.gold,
              onTap: onBoostTap,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.barChart,
              label: 'Rapor',
              color: AppColors.blue,
              onTap: onReportTap,
            ),
            if (onBulkPricingTap != null)
              _AnimatedQuickActionButton(
                width: itemWidth,
                icon: Icons.sell_outlined,
                label: 'Toplu Kâr',
                color: AppColors.info,
                onTap: onBulkPricingTap,
              ),
            _AnimatedQuickActionButton(
              key: openSlotKey,
              width: itemWidth,
              icon: Icons.add_business_rounded,
              label: 'Yeni Raf',
              color: AppColors.gold,
              onTap: canOpenNewSlot ? onOpenSlotTap : null,
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedQuickActionButton extends StatefulWidget {
  final double width;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AnimatedQuickActionButton({
    super.key,
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_AnimatedQuickActionButton> createState() => _AnimatedQuickActionButtonState();
}

class _AnimatedQuickActionButtonState extends State<_AnimatedQuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
      AppHaptic.light();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    final displayColor = isDisabled ? AppColors.textMuted : widget.color;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isDisabled
                  ? AppColors.border.withValues(alpha: 0.15)
                  : displayColor.withValues(alpha: 0.35),
              width: 1.1,
            ),
            boxShadow: [
              if (!isDisabled)
                BoxShadow(
                  color: displayColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? AppColors.cardBgLight.withValues(alpha: 0.3)
                      : displayColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isDisabled
                        ? AppColors.transparent
                        : displayColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: displayColor,
                  size: 18.sp,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.standardCopyWith(
                  color: isDisabled
                      ? AppColors.textMuted
                      : AppColors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
