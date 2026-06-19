import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({super.key});

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
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

  Future<void> _markRead(PlayerNotificationModel notification) async {
    if (!notification.isUnread) return;

    final result = await ref
        .read(notificationActionProvider)
        .markRead(notification.id);
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

  Future<void> _openAlert(PlayerNotificationModel notification) async {
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
            const SecondaryTopBar(title: 'Uyarilar'),
            Expanded(
              child: dashboardAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.red, fontSize: 12.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (dashboard) {
                  final activeAlerts = _sortAlerts(
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
                        if (activeAlerts.isEmpty)
                          _buildEmptyState()
                        else
                          ...activeAlerts.map(
                            (notification) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _buildAlertCard(notification),
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

  Widget _buildAlertCard(PlayerNotificationModel notification) {
    final accent = _severityColor(notification);
    final route = _targetRoute(notification);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAlert(notification),
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
                  _alertIcon(notification),
                  color: accent,
                  size: 20.sp,
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
                        _buildBadge(_alertTypeLabel(notification), accent),
                        if (_reasonLabel(notification) != null)
                          _buildBadge(
                            _reasonLabel(notification)!,
                            AppColors.textMuted,
                          ),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      notification.message,
                      style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 10.sp,
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
                              icon: const Icon(Icons.done_rounded),
                              label: const Text('Okundu Yap'),
                            ),
                          ),
                        if (notification.isUnread && route != null)
                          SizedBox(width: 8.w),
                        if (route != null)
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _openAlert(notification),
                              icon: const Icon(Icons.open_in_new_rounded),
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
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
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
              Icons.shield_outlined,
              color: AppColors.textMuted,
              size: 28.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Goruntulenecek aktif uyari yok.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      );

  List<PlayerNotificationModel> _sortAlerts(List<PlayerNotificationModel> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aPriority = _priorityOf(a);
      final bPriority = _priorityOf(b);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _priorityOf(PlayerNotificationModel item) {
    if (item.isActiveWarning) return 0;
    if (item.isActiveReminder) return 1;
    if (item.isUnread) return 2;
    return 3;
  }

  String? _targetRoute(PlayerNotificationModel notification) {
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

  IconData _alertIcon(PlayerNotificationModel item) {
    switch (item.category) {
      case 'store_blocked':
        return Icons.storefront_outlined;
      case 'production_blocked':
        return Icons.warning_amber_rounded;
      case 'logistics_attention':
        return Icons.local_shipping_outlined;
      case 'inactive_reminder':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _alertTypeLabel(PlayerNotificationModel item) {
    if (item.isActiveReminder) return 'Hatirlatma';
    return 'Uyari';
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
        return 'Ciftlik';
      case 'field':
        return 'Tarla';
      case 'mine':
        return 'Maden';
      case 'logistics':
        return 'Nakliye';
      default:
        return null;
    }
  }

  String? _reasonLabel(PlayerNotificationModel item) {
    switch (item.category) {
      case 'store_blocked':
        if (item.title.contains('Bos Slot')) return 'Bos Slot';
        if (item.title.contains('Stok Bitti')) return 'Stok Yok';
        return 'Magaza';
      case 'production_blocked':
        if (item.title.contains('Hammadde Eksik')) return 'Hammadde';
        if (item.title.contains('Secili Degil')) return 'Urun Secilmemis';
        if (item.title.contains('Deposu Dolu')) return 'Kapasite';
        if (item.title.contains('Bos Uretim Slotu')) return 'Bos Slot';
        return 'Uretim';
      case 'logistics_attention':
        if (item.title.contains('Pasif')) return 'Pasif';
        if (item.title.contains('Yakit')) return 'Yakit';
        if (item.title.contains('Kondisyon')) return 'Bakim';
        return 'Nakliye';
      case 'inactive_reminder':
        return 'Pasif';
      default:
        return null;
    }
  }

  Color _severityColor(PlayerNotificationModel item) {
    switch (item.severity) {
      case 'success':
        return AppColors.green;
      case 'warning':
        return Colors.orange;
      default:
        return AppColors.gold;
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
