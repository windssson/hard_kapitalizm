import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/notification/models/game_notification_model.dart';
import 'package:hard_kapitalizm/main.dart';

// ============================================================================
// TOAST VERİ MODELİ
// ============================================================================

class InGameToastData {
  final String id;
  final String title;
  final String message;
  final String? categoryLabel;
  final IconData icon;
  final Color color;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final String? timeAgo;

  const InGameToastData({
    required this.id,
    required this.title,
    required this.message,
    this.categoryLabel,
    required this.icon,
    required this.color,
    this.duration = const Duration(milliseconds: 3800),
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.timeAgo,
  });
}

// ============================================================================
// UNIFIED TOAST MANAGER (MERKEZİ YÖNETİCİ)
// ============================================================================

class InGameToastManager {
  static OverlayEntry? _currentEntry;
  static _InGameToastWidgetState? _activeState;

  static void show(InGameToastData data, {BuildContext? context}) {
    // Halihazırda gösterilen bir toast varsa akıcı şekilde kapat ve yenisini aç
    if (_activeState != null && _activeState!.mounted) {
      _activeState!.dismissWithAnimation(onCompleted: () {
        _insertNewEntry(data, context: context);
      });
      return;
    }

    _removeCurrentEntry();
    _insertNewEntry(data, context: context);
  }

  static void hide() {
    if (_activeState != null && _activeState!.mounted) {
      _activeState!.dismissWithAnimation(onCompleted: _removeCurrentEntry);
    } else {
      _removeCurrentEntry();
    }
  }

  static void _removeCurrentEntry() {
    _currentEntry?.remove();
    _currentEntry = null;
    _activeState = null;
  }

  static void _insertNewEntry(InGameToastData data, {BuildContext? context}) {
    OverlayState? overlay;
    if (context != null && context.mounted) {
      overlay = Overlay.of(context, rootOverlay: true);
    }
    overlay ??= rootNavigatorKey.currentState?.overlay;

    if (overlay == null) {
      debugPrint('[TOAST][DROPPED] Overlay bulunamadı: ${data.message}');
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _InGameToastWidget(
        key: ValueKey(data.id),
        data: data,
        onRegisterState: (state) => _activeState = state,
        onDismiss: () {
          if (_currentEntry == entry) {
            _removeCurrentEntry();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

// ============================================================================
// OYUN İÇİ BİLDİRİM KÖPRÜSÜ (GameNotification -> Unified Toast)
// ============================================================================

class InGameNotificationBanner {
  static void show(BuildContext context, GameNotification notification) {
    InGameToastManager.show(
      InGameToastData(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        categoryLabel: notification.categoryLabel.toUpperCase(),
        icon: notification.categoryIcon,
        color: notification.categoryColor,
        timeAgo: notification.timeAgo,
        duration: const Duration(milliseconds: 4500),
        onTap: () => _handleNavigation(context, notification),
      ),
      context: context,
    );
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
      case 'tender':
        context.push('/tenders');
        break;
      case 'arge':
      case 'research':
        context.push('/arge');
        break;
      case 'construction':
      case 'building_upgrade':
      case 'upgrade':
        context.push('/home');
        break;
      default:
        context.push('/notifications');
    }
  }
}

// ============================================================================
// GÖRSEL TOAST BİLEŞENİ (PREMIUM TOP-FLOATING CARD)
// ============================================================================

class _InGameToastWidget extends StatefulWidget {
  final InGameToastData data;
  final ValueChanged<_InGameToastWidgetState> onRegisterState;
  final VoidCallback onDismiss;

  const _InGameToastWidget({
    super.key,
    required this.data,
    required this.onRegisterState,
    required this.onDismiss,
  });

  @override
  State<_InGameToastWidget> createState() => _InGameToastWidgetState();
}

class _InGameToastWidgetState extends State<_InGameToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    widget.onRegisterState(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.data.duration, () {
      if (mounted) {
        dismissWithAnimation();
      }
    });
  }

  void dismissWithAnimation({VoidCallback? onCompleted}) {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
        onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final color = widget.data.color;

    return Positioned(
      top: topPadding + 6.h,
      left: 12.w,
      right: 12.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: ValueKey(widget.data.id),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _dismissTimer?.cancel();
              widget.onDismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.cardBg.withValues(alpha: 0.96),
                          AppColors.cardBgLight.withValues(alpha: 0.92),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: color.withValues(alpha: 0.45),
                        width: 1.2.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.22),
                          blurRadius: 18.r,
                          spreadRadius: 1.r,
                          offset: Offset(0, 4.h),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 14.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: widget.data.onTap != null
                          ? () {
                              dismissWithAnimation();
                              widget.data.onTap!();
                            }
                          : null,
                      borderRadius: BorderRadius.circular(16.r),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sol durum renk vurgusu (Neon Pillar)
                            Container(
                              width: 4.5.w,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    color,
                                    color.withValues(alpha: 0.4),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.8),
                                    blurRadius: 6.r,
                                    spreadRadius: 1.r,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),

                            // İkon Rozeti
                            Center(
                              child: Container(
                                width: 36.w,
                                height: 36.w,
                                margin: EdgeInsets.symmetric(vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.35),
                                    width: 1.w,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.15),
                                      blurRadius: 8.r,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.data.icon,
                                  color: color,
                                  size: 19.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),

                            // Metin Alanı
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 10.h,
                                  horizontal: 2.w,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Kategori / Tür Satırı
                                    Row(
                                      children: [
                                        Container(
                                          width: 5.5.w,
                                          height: 5.5.w,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: color,
                                                blurRadius: 4.r,
                                                spreadRadius: 1.r,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          (widget.data.categoryLabel ?? 'BİLDİRİM')
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 8.sp,
                                            fontWeight: FontWeight.w900,
                                            color: color,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (widget.data.timeAgo != null)
                                          Text(
                                            widget.data.timeAgo!,
                                            style: TextStyle(
                                              fontSize: 7.5.sp,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: dismissWithAnimation,
                                            child: Icon(
                                              Icons.close,
                                              size: 14.sp,
                                              color: AppColors.textMuted
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),

                                    // Başlık
                                    if (widget.data.title.isNotEmpty)
                                      Text(
                                        widget.data.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),

                                    // Mesaj
                                    Text(
                                      widget.data.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        color: AppColors.textSecondary,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Opsiyonel Aksiyon Butonu
                            if (widget.data.actionLabel != null &&
                                widget.data.onAction != null) ...[
                              SizedBox(width: 6.w),
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(right: 8.w),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      backgroundColor:
                                          color.withValues(alpha: 0.15),
                                      side: BorderSide(
                                        color: color.withValues(alpha: 0.4),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                    ),
                                    onPressed: () {
                                      dismissWithAnimation();
                                      widget.data.onAction!();
                                    },
                                    child: Text(
                                      widget.data.actionLabel!,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(width: 4.w),
                          ],
                        ),
                      ),
                    ),
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
