import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

enum _NotificationFilter {
  all('Tum'),
  active('Aktif Sorunlar'),
  events('Tamamlananlar'),
  warnings('Uyarilar');

  const _NotificationFilter(this.label);
  final String label;
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationActionProvider).refreshAttention();
    });
  }

  Future<void> _refresh() async {
    await ref.read(notificationActionProvider).refreshAttention();
    await ref.read(playerNotificationDashboardProvider.future);
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
                  final filtered = _sortNotifications(
                    _applyFilter(dashboard.notifications),
                  );
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                      children: [
                        _buildOverviewCard(dashboard.unreadCount, dashboard.activeWarningCount),
                        SizedBox(height: 12.h),
                        _buildFilterBar(),
                        SizedBox(height: 12.h),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _markAllRead,
                            child: const Text('Tumunu Okundu Yap'),
                          ),
                        ),
                        if (filtered.isEmpty)
                          _buildEmptyState()
                        else
                          ...filtered.map(
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

  Widget _buildOverviewCard(int unreadCount, int warningCount) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat('Okunmamis', '$unreadCount', AppColors.gold)),
          SizedBox(width: 8.w),
          Expanded(child: _buildMiniStat('Aktif Uyari', '$warningCount', Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final filter = _NotificationFilter.values[index];
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.14)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected ? AppColors.gold : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.gold : Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemCount: _NotificationFilter.values.length,
      ),
    );
  }

  Widget _buildNotificationCard(PlayerNotificationModel notification) {
    final accent = _severityColor(notification);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNotification(notification),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: notification.isUnread
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
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
                child: Icon(_notificationIcon(notification), color: accent, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: [
                                  _buildBadge(
                                    _kindLabel(notification),
                                    accent,
                                  ),
                                  if (_reasonLabel(notification) != null)
                                    _buildBadge(
                                      _reasonLabel(notification)!,
                                      AppColors.textMuted,
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
                            ],
                          ),
                        ),
                        if (notification.isUnread)
                          Padding(
                            padding: EdgeInsets.only(top: 2.h),
                            child: Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
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
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      'Bu filtre icin bildirim bulunamadi.',
      textAlign: TextAlign.center,
      style: AppTextStyles.body.copyWith(fontSize: 12.sp),
    ),
  );

  List<PlayerNotificationModel> _applyFilter(List<PlayerNotificationModel> items) {
    switch (_selectedFilter) {
      case _NotificationFilter.all:
        return items;
      case _NotificationFilter.active:
        return items
            .where((item) => item.isActiveWarning || item.isActiveReminder)
            .toList();
      case _NotificationFilter.events:
        return items.where((item) => item.kind == 'event').toList();
      case _NotificationFilter.warnings:
        return items.where((item) => item.kind == 'warning').toList();
    }
  }

  List<PlayerNotificationModel> _sortNotifications(
    List<PlayerNotificationModel> items,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final priorityCompare = _priorityOf(a).compareTo(_priorityOf(b));
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _priorityOf(PlayerNotificationModel item) {
    if (item.kind == 'warning' && item.status != 'resolved') return 0;
    if (item.isActiveReminder) return 1;
    if (item.isUnread) return 2;
    return 3;
  }

  String? _targetRoute(PlayerNotificationModel notification) {
    if (notification.category == 'transfer_completed') {
      return '/transfer-map';
    }

    if (notification.category == 'arge_completed') {
      return '/arge';
    }

    if (notification.entityKind == 'logistics') {
      return '/logistics';
    }

    final entityId = notification.entityId;
    switch (notification.entityKind) {
      case 'store':
        return entityId?.isNotEmpty == true ? '/store/$entityId' : '/store';
      case 'warehouse':
        return entityId?.isNotEmpty == true ? '/warehouses/$entityId' : '/warehouses';
      case 'factory':
        return entityId?.isNotEmpty == true ? '/factories/$entityId' : '/factories';
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
        return Icons.construction_rounded;
      case 'upgrade_completed':
        return Icons.trending_up_rounded;
      case 'transfer_completed':
        return Icons.local_shipping_rounded;
      case 'arge_completed':
        return Icons.science_rounded;
      case 'store_blocked':
        return Icons.storefront_outlined;
      case 'production_blocked':
        return Icons.warning_amber_rounded;
      case 'logistics_attention':
        return Icons.local_shipping_outlined;
      case 'inactive_reminder':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _kindLabel(PlayerNotificationModel item) {
    if (item.kind == 'warning') {
      return 'Uyari';
    }

    switch (item.category) {
      case 'construction_completed':
        return 'Insaat Tamam';
      case 'upgrade_completed':
        return 'Yukseltme Tamam';
      case 'transfer_completed':
        return 'Transfer Tamam';
      case 'arge_completed':
        return 'AR-GE Tamam';
      case 'logistics_attention':
        return 'Nakliye Uyarisi';
      case 'inactive_reminder':
        return 'Hatirlatma';
      default:
        return 'Bilgi';
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
