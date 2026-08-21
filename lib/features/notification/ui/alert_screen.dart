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

class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({super.key});

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  String _selectedFilter = 'all'; // 'all', 'store', 'production', 'logistics', 'tender'

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

    final result =
        await ref.read(notificationActionProvider).markRead(notification.id);
    if (!mounted) return;

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Güncellendi',
        message: 'Uyarı okundu olarak işaretlendi.',
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
            const SecondaryTopBar(title: 'İşletme Uyarıları'),
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
                  final allAlerts = _sortAlerts(
                    dashboard.notifications
                        .where(
                          (item) =>
                              item.isActiveWarning || item.isActiveReminder,
                        )
                        .toList(),
                  );

                  final filteredAlerts = allAlerts.where((item) {
                    if (_selectedFilter == 'all') return true;
                    if (_selectedFilter == 'store') {
                      return item.entityKind == 'store' ||
                          item.category.contains('store');
                    }
                    if (_selectedFilter == 'production') {
                      return item.entityKind == 'factory' ||
                          item.entityKind == 'farm' ||
                          item.entityKind == 'field' ||
                          item.entityKind == 'mine' ||
                          item.category.contains('production');
                    }
                    if (_selectedFilter == 'logistics') {
                      return item.entityKind == 'logistics' ||
                          item.category.contains('logistics');
                    }
                    if (_selectedFilter == 'tender') {
                      return item.entityKind == 'player_tender' ||
                          item.entityKind == 'tender_bid' ||
                          item.category.contains('tender');
                    }
                    return true;
                  }).toList();

                  return RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.cardBg,
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 30.h),
                      children: [
                        // --- HEALTH / STATUS BANNER ---
                        _buildStatusBanner(allAlerts.length),
                        SizedBox(height: 12.h),

                        // --- CATEGORY FILTER PILLS ---
                        if (allAlerts.isNotEmpty) ...[
                          _buildFilterChips(allAlerts),
                          SizedBox(height: 12.h),
                        ],

                        // --- ALERTS LIST ---
                        if (filteredAlerts.isEmpty)
                          _buildEmptyState(
                            isFiltered: _selectedFilter != 'all' &&
                                allAlerts.isNotEmpty,
                          )
                        else
                          ...filteredAlerts.asMap().entries.map((entry) {
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
                                child: _buildAlertCard(notification),
                              ),
                            );
                          }),
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

  Widget _buildStatusBanner(int count) {
    final bool hasIssues = count > 0;
    final accentColor = hasIssues ? AppColors.warning : AppColors.green;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            AppColors.cardBg.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 12.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5.w,
              ),
            ),
            child: Icon(
              hasIssues
                  ? AppIcons.warningAmberRounded
                  : AppIcons.shieldOutlined,
              color: accentColor,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasIssues
                      ? '$count İşletmede Aksiyon Bekleniyor'
                      : 'Tüm İşletmeler Güvende & Aktif',
                  style: AppTextStyles.titleBold.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.titleLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  hasIssues
                      ? 'Üretim veya satışın durmaması için aşağıdaki uyarılara müdahale edin.'
                      : 'Şirketinizde bekleyen kritik bir uyarı veya tıkanıklık yok.',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<PlayerNotificationModel> alerts) {
    final storeCount = alerts
        .where(
          (a) => a.entityKind == 'store' || a.category.contains('store'),
        )
        .length;
    final prodCount = alerts
        .where(
          (a) =>
              a.entityKind == 'factory' ||
              a.entityKind == 'farm' ||
              a.entityKind == 'field' ||
              a.entityKind == 'mine' ||
              a.category.contains('production'),
        )
        .length;
    final logCount = alerts
        .where(
          (a) =>
              a.entityKind == 'logistics' ||
              a.category.contains('logistics'),
        )
        .length;
    final tenderCount = alerts
        .where(
          (a) =>
              a.entityKind == 'player_tender' ||
              a.entityKind == 'tender_bid' ||
              a.category.contains('tender'),
        )
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'Tümü (${alerts.length})'),
          if (storeCount > 0) ...[
            SizedBox(width: 6.w),
            _buildFilterChip('store', 'Mağaza ($storeCount)'),
          ],
          if (prodCount > 0) ...[
            SizedBox(width: 6.w),
            _buildFilterChip('production', 'Üretim ($prodCount)'),
          ],
          if (logCount > 0) ...[
            SizedBox(width: 6.w),
            _buildFilterChip('logistics', 'Nakliye ($logCount)'),
          ],
          if (tenderCount > 0) ...[
            SizedBox(width: 6.w),
            _buildFilterChip('tender', 'İhale ($tenderCount)'),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = id),
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.border.withValues(alpha: 0.35),
            width: 1.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.goldLight : AppColors.textMuted,
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
        onTap: () => _openAlert(notification),
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
              color: accent.withValues(alpha: 0.5),
              width: 1.2.w,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 10.r,
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
                        color: accent.withValues(alpha: 0.45),
                        width: 1.w,
                      ),
                    ),
                    child: Icon(
                      _alertIcon(notification),
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
                      onTap: () => _openAlert(notification),
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
                              'Hemen Müdahale Et',
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

  Widget _buildEmptyState({bool isFiltered = false}) {
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
              color: AppColors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.35),
                width: 1.5.w,
              ),
            ),
            child: Icon(
              isFiltered
                  ? AppIcons.filterListOffRounded
                  : AppIcons.checkCircleRounded,
              color: AppColors.green,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            isFiltered
                ? 'Bu kategoride uyarı yok'
                : 'Tertemiz! Aktif Uyarı Bulunmuyor',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.titleLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isFiltered
                ? 'Seçili filtreye ait herhangi bir sorun veya aksiyon bulunmuyor.'
                : 'Tüm fabrikaların, mağazaların ve nakliyelerin sorunsuz çalışıyor patron.',
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

  List<PlayerNotificationModel> _sortAlerts(
    List<PlayerNotificationModel> items,
  ) {
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
      case 'player_tender':
        return entityId?.isNotEmpty == true
            ? '/tenders/player/$entityId'
            : '/tenders';
      case 'market':
        return '/market';
      default:
        return null;
    }
  }

  IconData _alertIcon(PlayerNotificationModel item) {
    switch (item.category) {
      case 'store_blocked':
        return AppIcons.storefrontOutlined;
      case 'production_blocked':
        return AppIcons.warningAmberRounded;
      case 'logistics_attention':
        return AppIcons.localShippingOutlined;
      case 'inactive_reminder':
        return AppIcons.pauseCircleOutlineRounded;
      case 'tender_failed':
      case 'tender_lost':
      case 'tender_cancelled':
      case 'tender_delivery_late':
        return AppIcons.gavelRounded;
      case 'market_sale':
        return AppIcons.paymentsRounded;
      default:
        return AppIcons.notificationsActiveOutlined;
    }
  }

  String _alertTypeLabel(PlayerNotificationModel item) {
    if (item.isActiveReminder) return 'Hatırlatma';
    return 'Uyarı';
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

  String? _reasonLabel(PlayerNotificationModel item) {
    switch (item.category) {
      case 'store_blocked':
        if (item.title.contains('Bos Slot') ||
            item.title.contains('Boş Slot')) {
          return 'Boş Slot';
        }
        if (item.title.contains('Stok Bitti')) return 'Stok Yok';
        return 'Mağaza';
      case 'production_blocked':
        if (item.title.contains('Hammadde Eksik')) return 'Hammadde';
        if (item.title.contains('Secili Degil') ||
            item.title.contains('Seçili Değil')) {
          return 'Ürün Seçilmemiş';
        }
        if (item.title.contains('Deposu Dolu')) return 'Kapasite';
        if (item.title.contains('Bos Uretim Slotu') ||
            item.title.contains('Boş Üretim Slotu')) {
          return 'Boş Slot';
        }
        return 'Üretim';
      case 'logistics_attention':
        if (item.title.contains('Pasif')) return 'Pasif';
        if (item.title.contains('Yakit') || item.title.contains('Yakıt')) {
          return 'Yakıt';
        }
        if (item.title.contains('Kondisyon') ||
            item.title.contains('Bakım')) {
          return 'Bakım';
        }
        return 'Nakliye';
      case 'inactive_reminder':
        return 'Pasif';
      case 'tender_failed':
        return 'Süre Aşımı';
      case 'tender_lost':
        return 'Teklif Kaybı';
      case 'tender_cancelled':
        return 'İptal';
      case 'tender_delivery_late':
        return 'Geç Teslimat';
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
        return AppColors.gold;
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
