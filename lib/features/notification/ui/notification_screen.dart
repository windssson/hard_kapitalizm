import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationActionProvider).refreshAttention();
    });
  }

  Future<void> _refresh() async {
    await ref.read(notificationActionProvider).refreshAttention();
    final _ = await ref.refresh(playerNotificationDashboardProvider.future);
  }

  Future<void> _markAllRead() async {
    final result = await ref.read(notificationActionProvider).markAllRead();
    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Tüm bildirimler okundu olarak işaretlendi.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _markRead(PlayerNotificationModel notification) async {
    if (!notification.isUnread) return;
    final result =
        await ref.read(notificationActionProvider).markRead(notification.id);
    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Güncellendi',
        message: 'Bildirim okundu olarak işaretlendi.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _openNotification(PlayerNotificationModel notification) async {
    if (notification.isUnread) {
      await ref.read(notificationActionProvider).markRead(notification.id);
    }

    if (!mounted) return;

    final route = _targetRoute(notification);
    if (route != null) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(playerNotificationDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Bildirim Merkezi'),
            Expanded(
              child: dashboardAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.body,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (dashboard) {
                  final unreadNotifications = _sortNotifications(
                    dashboard.notifications
                        .where((item) => item.isEvent && item.isUnread)
                        .toList(),
                  );

                  final allEvents = _sortNotifications(
                    dashboard.notifications
                        .where((item) => item.isEvent)
                        .toList(),
                  );

                  final activeAlerts = _sortNotifications(
                    dashboard.notifications
                        .where(
                          (item) =>
                              item.isActiveWarning || item.isActiveReminder,
                        )
                        .toList(),
                  );

                  return RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.cardBg,
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 30.h),
                      children: [
                        // --- STATS OVERVIEW CARD ---
                        _buildOverviewCard(
                          unreadEventsCount: unreadNotifications.length,
                          totalEventsCount: allEvents.length,
                          alertsCount: activeAlerts.length,
                          onMarkAllRead: unreadNotifications.isNotEmpty
                              ? _markAllRead
                              : null,
                        ),
                        SizedBox(height: 14.h),

                        // --- SEGMENTED TAB SWITCHER ---
                        _buildTabSwitcher(
                          eventsCount: unreadNotifications.length,
                          alertsCount: activeAlerts.length,
                        ),
                        SizedBox(height: 14.h),

                        if (_currentTabIndex == 0) ...[
                          // --- EVENTS TAB ---
                          if (allEvents.isEmpty)
                            _buildEmptyState(
                              title: 'Henüz bir bildirim yok',
                              subtitle:
                                  'Şirketindeki üretim, satış ve ihale hareketleri burada görünecek.',
                              icon: AppIcons.notificationsOffRounded,
                            )
                          else
                            ...allEvents.asMap().entries.map((entry) {
                              final index = entry.key;
                              final notification = entry.value;
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: Duration(
                                  milliseconds: 200 + (index * 40).clamp(0, 400),
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 16 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: _buildNotificationCard(notification),
                                ),
                              );
                            }),
                        ] else ...[
                          // --- ALERTS TAB ---
                          if (activeAlerts.isEmpty)
                            _buildEmptyState(
                              title: 'Her Şey Yolunda!',
                              subtitle:
                                  'İşletmelerinde bekleyen veya müdahale gerektiren bir sorun bulunmuyor patron.',
                              icon: AppIcons.checkCircleRounded,
                              iconColor: AppColors.green,
                            )
                          else
                            ...activeAlerts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final alert = entry.value;
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: Duration(
                                  milliseconds: 200 + (index * 40).clamp(0, 400),
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 16 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: _buildAlertCard(alert),
                                ),
                              );
                            }),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required int unreadEventsCount,
    required int totalEventsCount,
    required int alertsCount,
    required VoidCallback? onMarkAllRead,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBgLight.withValues(alpha: 0.8),
            AppColors.cardBg.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.3),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.25),
            blurRadius: 12.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildOverviewStat(
                label: 'Okunmamış',
                value: unreadEventsCount.toString(),
                color: unreadEventsCount > 0
                    ? AppColors.gold
                    : AppColors.textMuted,
                icon: AppIcons.markEmailUnreadRounded,
              ),
              Container(
                width: 1.w,
                height: 32.h,
                color: AppColors.border.withValues(alpha: 0.4),
              ),
              _buildOverviewStat(
                label: 'Aktif Uyarı',
                value: alertsCount.toString(),
                color: alertsCount > 0 ? AppColors.warning : AppColors.green,
                icon: alertsCount > 0
                    ? AppIcons.warningAmberRounded
                    : AppIcons.checkCircleOutlineRounded,
              ),
              Container(
                width: 1.w,
                height: 32.h,
                color: AppColors.border.withValues(alpha: 0.4),
              ),
              _buildOverviewStat(
                label: 'Toplam Olay',
                value: totalEventsCount.toString(),
                color: AppColors.textPrimary,
                icon: AppIcons.notificationsNoneRounded,
              ),
            ],
          ),
          if (onMarkAllRead != null) ...[
            SizedBox(height: 10.h),
            Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.3),
            ),
            SizedBox(height: 10.h),
            InkWell(
              onTap: onMarkAllRead,
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 1.w,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.doneAllRounded,
                      size: 15.sp,
                      color: AppColors.goldLight,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Tüm Olayları Okundu Olarak İşaretle',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.goldLight,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.h2.standardCopyWith(
                  color: color,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher({
    required int eventsCount,
    required int alertsCount,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.25),
          width: 1.w,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              label: 'Olaylar & Geçmiş',
              badgeCount: eventsCount,
              badgeColor: AppColors.gold,
              icon: AppIcons.notificationsActiveRounded,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: _buildTabButton(
              index: 1,
              label: 'İşletme Uyarıları',
              badgeCount: alertsCount,
              badgeColor: AppColors.warning,
              icon: AppIcons.warningAmberRounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int badgeCount,
    required Color badgeColor,
    required IconData icon,
  }) {
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 9.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.gold.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: isSelected
              ? Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  width: 1.w,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15.sp,
              color: isSelected ? AppColors.goldLight : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: isSelected ? AppColors.white : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: AppTypography.bodySmall,
              ),
            ),
            if (badgeCount > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.6),
                    width: 0.8.w,
                  ),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(PlayerNotificationModel notification) {
    final accent = _severityColor(notification);
    final route = _targetRoute(notification);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _openNotification(notification),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(13.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                notification.isUnread
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.cardBgLight.withValues(alpha: 0.5),
                AppColors.cardBg.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: notification.isUnread
                  ? accent.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.35),
              width: notification.isUnread ? 1.4.w : 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: notification.isUnread
                    ? accent.withValues(alpha: 0.08)
                    : AppColors.black.withValues(alpha: 0.15),
                blurRadius: 10.r,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Badges + Relative Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 1.w,
                      ),
                    ),
                    child: Icon(
                      _notificationIcon(notification),
                      color: accent,
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Wrap(
                      spacing: 5.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildBadge(_kindLabel(notification), accent),
                        if (_entityLabel(notification) != null)
                          _buildBadge(
                            _entityLabel(notification)!,
                            AppColors.blue,
                          ),
                        if (notification.isUnread)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold,
                                  AppColors.goldDark,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'YENİ',
                              style: TextStyle(
                                color: AppColors.textOnAccent,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.scheduleRounded,
                        size: 12.sp,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: AppTextStyles.caption.standardCopyWith(
                          fontSize: AppTypography.micro,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Title
              Text(
                notification.title,
                style: AppTextStyles.titleBold.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),

              // Message Body
              Text(
                notification.message,
                style: AppTextStyles.body.standardCopyWith(
                  fontSize: AppTypography.bodySmall,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              // Bottom Action Bar
              if (route != null || notification.isUnread) ...[
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (notification.isUnread)
                      TextButton.icon(
                        onPressed: () => _markRead(notification),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          AppIcons.doneRounded,
                          size: 14.sp,
                          color: AppColors.textMuted,
                        ),
                        label: Text(
                          'Okundu',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.caption,
                          ),
                        ),
                      ),
                    if (route != null) ...[
                      SizedBox(width: 8.w),
                      InkWell(
                        onTap: () => _openNotification(notification),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'İncele',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTypography.caption,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                AppIcons.arrowForwardRounded,
                                size: 13.sp,
                                color: accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(PlayerNotificationModel notification) {
    final accent = _severityColor(notification);
    final route = _targetRoute(notification);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => _openNotification(notification),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(13.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.12),
                AppColors.cardBg.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
              width: 1.3.w,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.1),
                blurRadius: 12.r,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 1.w,
                      ),
                    ),
                    child: Icon(
                      _notificationIcon(notification),
                      color: accent,
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Wrap(
                      spacing: 5.w,
                      runSpacing: 4.h,
                      children: [
                        _buildBadge(_kindLabel(notification), accent),
                        if (_entityLabel(notification) != null)
                          _buildBadge(
                            _entityLabel(notification)!,
                            AppColors.blue,
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.scheduleRounded,
                        size: 12.sp,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: AppTextStyles.caption.standardCopyWith(
                          fontSize: AppTypography.micro,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                notification.title,
                style: AppTextStyles.titleBold.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                notification.message,
                style: AppTextStyles.body.standardCopyWith(
                  fontSize: AppTypography.bodySmall,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (notification.isUnread)
                    TextButton.icon(
                      onPressed: () => _markRead(notification),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        AppIcons.doneRounded,
                        size: 14.sp,
                        color: AppColors.textMuted,
                      ),
                      label: Text(
                        'Okundu',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                    ),
                  if (route != null) ...[
                    SizedBox(width: 8.w),
                    InkWell(
                      onTap: () => _openNotification(notification),
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 1.w,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Modüle Git',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: AppTypography.caption,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              AppIcons.arrowForwardRounded,
                              size: 13.sp,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8.w),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    IconData icon = AppIcons.notificationsOffRounded,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? AppColors.gold;
    return Container(
      margin: EdgeInsets.only(top: 20.h),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.2),
          width: 1.w,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: effectiveColor.withValues(alpha: 0.35),
                width: 1.5.w,
              ),
            ),
            child: Icon(icon, color: effectiveColor, size: 30.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.titleLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  List<PlayerNotificationModel> _sortNotifications(
    List<PlayerNotificationModel> items,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  String? _targetRoute(PlayerNotificationModel notification) {
    if (notification.category == 'market_sale') {
      return '/market';
    }

    if (notification.category == 'transfer_completed') {
      return '/transfer-map';
    }

    if (notification.category == 'arge_completed') {
      return '/arge';
    }

    if (notification.category == 'achievement_unlocked') {
      return '/achievements';
    }

    if (notification.entityKind == 'player_tender') {
      final entityId = notification.entityId;
      return entityId?.isNotEmpty == true
          ? '/tenders/player/$entityId'
          : '/tenders';
    }

    if (notification.entityKind == 'tender_bid') {
      final tenderId = notification.meta['tender_id']?.toString();
      return tenderId?.isNotEmpty == true
          ? '/tenders/open/$tenderId'
          : '/tenders';
    }

    if (notification.entityKind == 'logistics') {
      return '/logistics';
    }

    final entityId = notification.entityId;
    switch (notification.entityKind) {
      case 'store':
        return entityId?.isNotEmpty == true ? '/store/$entityId' : '/store';
      case 'warehouse':
        return entityId?.isNotEmpty == true
            ? '/warehouses/$entityId'
            : '/warehouses';
      case 'factory':
        return entityId?.isNotEmpty == true
            ? '/factories/$entityId'
            : '/factories';
      case 'farm':
        return entityId?.isNotEmpty == true ? '/farms/$entityId' : '/farms';
      case 'field':
        return entityId?.isNotEmpty == true ? '/fields/$entityId' : '/fields';
      case 'mine':
        return entityId?.isNotEmpty == true ? '/mines/$entityId' : '/mines';
      case 'market':
        return '/market';
      default:
        return null;
    }
  }

  IconData _notificationIcon(PlayerNotificationModel item) {
    switch (item.category) {
      case 'market_sale':
        return AppIcons.paymentsRounded;
      case 'construction_completed':
        return AppIcons.constructionRounded;
      case 'upgrade_completed':
        return AppIcons.trendingUpRounded;
      case 'transfer_completed':
        return AppIcons.localShippingRounded;
      case 'arge_completed':
        return AppIcons.scienceRounded;
      case 'achievement_unlocked':
        return AppIcons.workspacePremiumRounded;
      case 'tender_accepted':
      case 'tender_won':
      case 'tender_completed':
        return AppIcons.gavelRounded;
      case 'tender_delivery_started':
      case 'tender_delivery_completed':
        return AppIcons.localShippingRounded;
      case 'tender_failed':
      case 'tender_lost':
      case 'tender_cancelled':
      case 'tender_delivery_late':
        return AppIcons.warningAmberRounded;
      case 'store_blocked':
        return AppIcons.storefrontOutlined;
      case 'production_blocked':
        return AppIcons.warningAmberRounded;
      case 'logistics_attention':
        return AppIcons.localShippingOutlined;
      case 'inactive_reminder':
        return AppIcons.pauseCircleOutlineRounded;
      default:
        return AppIcons.notificationsNoneRounded;
    }
  }

  String _kindLabel(PlayerNotificationModel item) {
    switch (item.category) {
      case 'market_sale':
        return 'Toptan Satış';
      case 'construction_completed':
        return 'İnşaat Tamam';
      case 'upgrade_completed':
        return 'Yükseltme Tamam';
      case 'transfer_completed':
        return 'Transfer Tamam';
      case 'arge_completed':
        return 'AR-GE Tamam';
      case 'achievement_unlocked':
        return 'Rozet Açıldı';
      case 'tender_accepted':
        return 'İhale Alındı';
      case 'tender_won':
        return 'İhale Kazanıldı';
      case 'tender_completed':
        return 'İhale Tamam';
      case 'tender_delivery_started':
        return 'Teslimat Başladı';
      case 'tender_delivery_completed':
        return 'Teslimat Ulaştı';
      case 'tender_failed':
        return 'İhale Başarısız';
      case 'tender_lost':
        return 'Teklif Kaybetti';
      case 'tender_cancelled':
        return 'İhale İptal';
      case 'tender_delivery_late':
        return 'Teslimat Gecikti';
      case 'store_blocked':
        return 'Mağaza Uyarısı';
      case 'production_blocked':
        return 'Üretim Uyarısı';
      case 'logistics_attention':
        return 'Lojistik Uyarısı';
      case 'inactive_reminder':
        return 'İşletme Hatırlatma';
      default:
        return 'Bilgi';
    }
  }

  String? _entityLabel(PlayerNotificationModel item) {
    switch (item.entityKind) {
      case 'store':
        return 'Mağaza';
      case 'warehouse':
        return 'Depo';
      case 'factory':
        return 'Fabrika';
      case 'farm':
        return 'Tarla';
      case 'field':
        return 'Çiftlik';
      case 'mine':
        return 'Maden';
      case 'player_tender':
        return 'İhale';
      case 'tender_bid':
        return 'Teklif';
      case 'logistics':
        return 'Nakliye';
      case 'market':
        return 'Pazar';
      default:
        return null;
    }
  }

  Color _severityColor(PlayerNotificationModel item) {
    switch (item.severity) {
      case 'success':
        return AppColors.green;
      case 'warning':
        return AppColors.warning;
      case 'danger':
        return AppColors.red;
      default:
        return AppColors.blue;
    }
  }

  String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} sa önce';
    return '${difference.inDays} gün önce';
  }
}
