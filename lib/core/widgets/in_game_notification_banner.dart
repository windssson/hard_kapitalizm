import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';

class InGameNotificationBanner {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, GameNotification notification) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InGameNotificationWidget(
        notification: notification,
        onDismiss: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
          }
        },
        onTap: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
          }
          _handleNavigation(context, notification);
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _handleNavigation(
    BuildContext context,
    GameNotification notification,
  ) {
    if (notification.entityType == null) {
      context.push('/notifications');
      return;
    }

    switch (notification.entityType!.toLowerCase()) {
      case 'market':
      case 'trade':
        context.push('/market');
        break;
      case 'transfer':
      case 'logistics':
        context.push('/logistics');
        break;
      case 'factory':
        context.push('/factory');
        break;
      case 'field':
      case 'farm':
        context.push('/agriculture');
        break;
      case 'mine':
        context.push('/mine');
        break;
      case 'building_upgrade':
      case 'upgrade':
        context.push('/home');
        break;
      default:
        context.push('/notifications');
    }
  }
}

class _InGameNotificationWidget extends StatefulWidget {
  final GameNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InGameNotificationWidget({
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InGameNotificationWidget> createState() =>
      _InGameNotificationWidgetState();
}

class _InGameNotificationWidgetState extends State<_InGameNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Auto-dismiss after 4.2 seconds
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  void _dismissWithAnimation() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
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
    final topPadding = MediaQuery.of(context).padding.top;
    final color = widget.notification.categoryColor;

    return Positioned(
      top: topPadding + 6.h,
      left: 10.w,
      right: 10.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: ValueKey(widget.notification.id),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: color.withValues(alpha: 0.6),
                      width: 1.2.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 18.r,
                        spreadRadius: 1.r,
                        offset: Offset(0, 4.h),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 12.r,
                        offset: Offset(0, 6.h),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                            width: 1.w,
                          ),
                        ),
                        child: Icon(
                          widget.notification.categoryIcon,
                          color: color,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.notification.categoryLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 7.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  widget.notification.timeAgo,
                                  style: TextStyle(
                                    fontSize: 7.sp,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              widget.notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.standardCopyWith(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              widget.notification.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.standardCopyWith(
                                fontSize: 8.sp,
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
