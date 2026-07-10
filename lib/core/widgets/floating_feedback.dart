import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

enum FloatingFeedbackType {
  cashAdd,
  cashRemove,
  xp,
  gold,
}

class FloatingFeedback {
  static void show(
    BuildContext context, {
    required double amount,
    required FloatingFeedbackType type,
    Offset? position,
  }) {
    if (!context.mounted) return;
    
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;
    
    final spawnPosition = position ?? Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height * 0.4,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FloatingTextWidget(
        amount: amount,
        type: type,
        initialPosition: spawnPosition,
        onComplete: () {
          entry.remove();
        },
      ),
    );

    overlayState.insert(entry);
  }
}

class _FloatingTextWidget extends StatefulWidget {
  final double amount;
  final FloatingFeedbackType type;
  final Offset initialPosition;
  final VoidCallback onComplete;

  const _FloatingTextWidget({
    required this.amount,
    required this.type,
    required this.initialPosition,
    required this.onComplete,
  });

  @override
  State<_FloatingTextWidget> createState() => _FloatingTextWidgetState();
}

class _FloatingTextWidgetState extends State<_FloatingTextWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;
  late final double _randomXOffset;

  @override
  void initState() {
    super.initState();
    _randomXOffset = (math.Random().nextDouble() - 0.5) * 50.w;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 65,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = widget.initialPosition.dy - (_controller.value * 100.h);
        final dx = widget.initialPosition.dx + (_randomXOffset * _controller.value);

        Color textColor;
        String prefix;
        String suffix = '';
        IconData icon;

        switch (widget.type) {
          case FloatingFeedbackType.cashAdd:
            textColor = AppColors.green;
            prefix = '+';
            suffix = ' TL';
            icon = AppIcons.paymentsOutlined;
            break;
          case FloatingFeedbackType.cashRemove:
            textColor = AppColors.red;
            prefix = '-';
            suffix = ' TL';
            icon = AppIcons.paymentsOutlined;
            break;
          case FloatingFeedbackType.xp:
            textColor = AppColors.gold;
            prefix = '+';
            suffix = ' XP';
            icon = AppIcons.militaryTechRounded;
            break;
          case FloatingFeedbackType.gold:
            textColor = AppColors.gold;
            prefix = '+';
            suffix = ' Altin';
            icon = AppIcons.starsRounded;
            break;
        }

        final amountStr = widget.amount % 1 == 0
            ? widget.amount.toInt().toString()
            : widget.amount.toStringAsFixed(1);

        return Positioned(
          left: dx - 60.w,
          top: dy,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Material(
                  color: AppColors.transparent,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppFx.panelWash(0.8),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.6),
                        width: 1.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: textColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: textColor, size: AppIconSizes.small),
                        SizedBox(width: 4.w),
                        Text(
                          '$prefix$amountStr$suffix',
                          style: AppTextStyles.label.standardCopyWith(
                            color: textColor,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
