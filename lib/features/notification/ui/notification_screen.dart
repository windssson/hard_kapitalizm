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
            const SecondaryTopBar(title: 'Bildirimler'),
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

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                      children: [
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
                          _buildEmptyState()
                        else
                          ...unreadNotifications.map(
                            (notification) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _buildNotificationCard(notification),
                            ),
                          ),
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

  Widget _buildEmptyState() => Container(
        padding: EdgeInsets.all(24.w),
        decoration: AppDecorations.premiumCard(AppColors.border, 16.r),
        child: Column(
          children: [
            Icon(
              AppIcons.notificationsOffRounded,
              color: AppColors.textMuted,
              size: AppIconSizes.xLarge,
            ),
            SizedBox(height: 8.h),
            Text(
              'Goruntulenecek okunmamis bildirim yok.',
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
