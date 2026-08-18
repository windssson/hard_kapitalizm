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
        title: 'Basarili',
        message: 'Tum bildirimler okundu olarak isaretlendi.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _markRead(PlayerNotificationModel notification) async {
    if (!notification.isUnread) return;
    final result = await ref.read(notificationActionProvider).markRead(notification.id);
    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Guncellendi',
        message: 'Uyari okundu olarak isaretlendi.',
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

                  final activeAlerts = _sortNotifications(
                    dashboard.notifications
                        .where((item) => item.isActiveWarning || item.isActiveReminder)
                        .toList(),
                  );

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                      children: [
                        // --- SEGMENTED TAB SWITCHER ---
                        _buildTabSwitcher(
                          eventsCount: unreadNotifications.length,
                          alertsCount: activeAlerts.length,
                        ),
                        SizedBox(height: 14.h),

                        if (_currentTabIndex == 0) ...[
                          // --- EVENTS TAB ---
                          if (unreadNotifications.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _markAllRead,
                                  icon: const Icon(AppIcons.doneAllRounded),
                                  label: const Text('Tumunu Okundu Yap'),
                                ),
                              ),
                            ),
                          if (unreadNotifications.isEmpty)
                            _buildEmptyState(
                              title: 'Goruntulenecek yeni bildirim yok.',
                              icon: AppIcons.notificationsOffRounded,
                            )
                          else
                            ...unreadNotifications.map(
                              (notification) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _buildNotificationCard(notification),
                              ),
                            ),
                        ] else ...[
                          // --- ALERTS TAB ---
                          if (activeAlerts.isEmpty)
                            _buildEmptyState(
                              title: 'Harika! Isletmelerinizde aktif bir sorun bulunmuyor.',
                              icon: AppIcons.checkCircleRounded,
                              iconColor: AppColors.green,
                            )
                          else
                            ...activeAlerts.map(
                              (alert) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _buildAlertCard(alert),
                              ),
                            ),
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

  Widget _buildTabSwitcher({required int eventsCount, required int alertsCount}) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              label: 'Olaylar',
              badgeCount: eventsCount,
              badgeColor: AppColors.gold,
              icon: AppIcons.notificationsNoneRounded,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: _buildTabButton(
              index: 1,
              label: 'Isletme Uyarilari',
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
      borderRadius: BorderRadius.circular(9.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBgLight : AppColors.transparent,
          borderRadius: BorderRadius.circular(9.r),
          border: isSelected
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15.sp,
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: AppTypography.caption,
              ),
            ),
            if (badgeCount > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.8),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: AppTextStyles.caption.standardCopyWith(
                    color: badgeColor,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
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
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: AppDecorations.premiumCard(accent, 14.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _notificationIcon(notification),
                  color: accent,
                  size: AppIconSizes.medium,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _buildBadge(_kindLabel(notification), accent),
                        if (_entityLabel(notification) != null)
                          _buildBadge(
                            _entityLabel(notification)!,
                            AppColors.blue,
                          ),
                        if (notification.isUnread)
                          _buildBadge('Yeni', AppColors.gold),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      notification.title,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      notification.message,
                      style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: AppTextStyles.body.standardCopyWith(
                        fontSize: AppTypography.label,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        if (notification.isUnread)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _markRead(notification),
                              icon: const Icon(AppIcons.doneRounded),
                              label: const Text('Okundu Yap'),
                            ),
                          ),
                        if (notification.isUnread && route != null)
                          SizedBox(width: 8.w),
                        if (route != null)
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _openNotification(notification),
                              icon: const Icon(AppIcons.openInNewRounded),
                              label: const Text('Module Git'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: AppDecorations.premiumCard(accent, 14.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _notificationIcon(notification),
                  color: accent,
                  size: AppIconSizes.medium,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _buildBadge(_kindLabel(notification), accent),
                        if (_entityLabel(notification) != null)
                          _buildBadge(
                            _entityLabel(notification)!,
                            AppColors.blue,
                          ),
                        _buildBadge('Yeni', AppColors.gold),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      notification.title,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      notification.message,
                      style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: AppTextStyles.body.standardCopyWith(
                        fontSize: AppTypography.label,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (route != null) ...[
                      SizedBox(height: 10.h),
                      FilledButton.tonalIcon(
                        onPressed: () => _openNotification(notification),
                        icon: const Icon(AppIcons.openInNewRounded),
                        label: const Text('Module Git'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    String title = 'Goruntulenecek yeni bildirim yok.',
    IconData icon = AppIcons.notificationsOffRounded,
    Color? iconColor,
  }) =>
      Container(
        padding: EdgeInsets.all(24.w),
        decoration: AppDecorations.premiumCard(AppColors.border, 16.r),
        child: Column(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppColors.textMuted,
              size: AppIconSizes.xLarge,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.body),
            ),
          ],
        ),
      );

  List<PlayerNotificationModel> _sortNotifications(
    List<PlayerNotificationModel> items,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  String? _targetRoute(PlayerNotificationModel notification) {
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
      return tenderId?.isNotEmpty == true ? '/tenders/open/$tenderId' : '/tenders';
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
      default:
        return null;
    }
  }

  IconData _notificationIcon(PlayerNotificationModel item) {
    switch (item.category) {
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
      default:
        return AppIcons.notificationsNoneRounded;
    }
  }

  String _kindLabel(PlayerNotificationModel item) {
    switch (item.category) {
      case 'construction_completed':
        return 'Insaat Tamam';
      case 'upgrade_completed':
        return 'Yukseltme Tamam';
      case 'transfer_completed':
        return 'Transfer Tamam';
      case 'arge_completed':
        return 'AR-GE Tamam';
      case 'achievement_unlocked':
        return 'Rozet Acildi';
      case 'tender_accepted':
        return 'Ihale Alindi';
      case 'tender_won':
        return 'Ihale Kazanildi';
      case 'tender_completed':
        return 'Ihale Tamam';
      case 'tender_delivery_started':
        return 'Teslimat Basladi';
      case 'tender_delivery_completed':
        return 'Teslimat Ulasti';
      case 'tender_failed':
        return 'Ihale Basarisiz';
      case 'tender_lost':
        return 'Teklif Kaybetti';
      case 'tender_cancelled':
        return 'Ihale Iptal';
      case 'tender_delivery_late':
        return 'Teslimat Gecikti';
      default:
        return 'Bilgi';
    }
  }

  String? _entityLabel(PlayerNotificationModel item) {
    switch (item.entityKind) {
      case 'store':
        return 'Magaza';
      case 'warehouse':
        return 'Depo';
      case 'factory':
        return 'Fabrika';
      case 'farm':
        return 'Tarla';
      case 'field':
        return 'Ciftlik';
      case 'mine':
        return 'Maden';
      case 'player_tender':
        return 'Ihale';
      case 'tender_bid':
        return 'Teklif';
      case 'logistics':
        return 'Nakliye';
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
      default:
        return AppColors.blue;
    }
  }

  String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Simdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk once';
    if (difference.inDays < 1) return '${difference.inHours} sa once';
    return '${difference.inDays} gun once';
  }
}
