import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class StoreQuickActions extends StatelessWidget {
  final bool canOpenNewSlot;
  final VoidCallback onUpgradeTap;
  final VoidCallback onBoostTap;
  final VoidCallback onReportTap;
  final VoidCallback? onOpenSlotTap;
  final VoidCallback onHistoryTap;

  const StoreQuickActions({
    super.key,
    required this.canOpenNewSlot,
    required this.onUpgradeTap,
    required this.onBoostTap,
    required this.onReportTap,
    required this.onOpenSlotTap,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = ((constraints.maxWidth - (4 * 6.w)) / 5).clamp(
          56.w,
          72.w,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.upgradeRounded,
              label: 'Yukselt',
              color: AppColors.green,
              onTap: onUpgradeTap,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.flashOnRounded,
              label: 'Boost',
              color: AppColors.goldDark,
              onTap: onBoostTap,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.barChart,
              label: 'Rapor',
              color: AppColors.purple,
              onTap: onReportTap,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.addBox,
              label: 'Slot Ac',
              color: AppColors.gold,
              onTap: canOpenNewSlot ? onOpenSlotTap : null,
            ),
            _AnimatedQuickActionButton(
              width: itemWidth,
              icon: AppIcons.history,
              label: 'Gecmis',
              color: AppColors.textPrimary,
              onTap: onHistoryTap,
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
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_AnimatedQuickActionButton> createState() => _AnimatedQuickActionButtonState();
}

class _AnimatedQuickActionButtonState extends State<_AnimatedQuickActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
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
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                displayColor.withValues(alpha: 0.15),
                displayColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: displayColor.withValues(alpha: 0.3)),
            boxShadow: [
              if (!isDisabled)
                BoxShadow(
                  color: displayColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: displayColor, size: AppIconSizes.medium),
              SizedBox(height: 5.h),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.standardCopyWith(
                  color: isDisabled ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
