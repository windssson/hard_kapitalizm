import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/app_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with RouteRefreshMixin<HomeScreen> {
  final int _selectedIndex = 0;

  @override
  void refreshRouteData() {
    Future.microtask(() async {
      await ref.read(notificationActionProvider).refreshAttention();
    });
    ref.invalidate(playerNotificationDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
                child: Column(
                  children: [
                    _buildCompanySummaryCard(),
                    SizedBox(height: 12.h),
                    _buildModuleGrid(),
                    SizedBox(height: 12.h),
                    _buildFinancialStats(),
                    SizedBox(height: 12.h),
                    _buildNewsSection(),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                if (index == _selectedIndex) return;
                switch (index) {
                  case 0:
                    context.go('/home');
                    break;
                  case 2:
                    context.go('/transfer-map');
                    break;
                  case 4:
                    context.go('/profile');
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySummaryCard() {
    return Consumer(
      builder: (context, ref, child) {
        final player = ref.watch(playerProvider).value;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116.w,
                  child: Column(
                    children: [
                      Container(
                        width: 96.w,
                        height: 96.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardBgLight,
                          border: Border.all(color: AppColors.gold, width: 3.w),
                        ),
                        child: ClipOval(
                          child: CachedAssetImage(
                            fileName: player?.avatarId ?? 'ae1.webp',
                            fit: BoxFit.cover,
                            placeholder: Icon(
                              Icons.person,
                              color: AppColors.gold,
                              size: 42.sp,
                            ),
                            errorWidget: Icon(
                              Icons.person,
                              color: AppColors.gold,
                              size: 42.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBg,
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Text(
                          'Lv. ${player?.level ?? 1}',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        player?.playerName ?? 'CEO',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SIRKET OZETI', style: AppTextStyles.titleGold),
                      SizedBox(height: 10.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sirket Degeri', style: AppTextStyles.body),
                                SizedBox(height: 2.h),
                                Text(
                                  _formatMoney(player?.cash ?? 0),
                                  style: AppTextStyles.statValue,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.bar_chart,
                            color: AppColors.gold,
                            size: 34.sp,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Divider(color: AppColors.border, height: 1.h),
                      SizedBox(height: 10.h),
                      _buildSummaryRow(
                        Icons.show_chart,
                        'Gunluk Kar',
                        '+1.28M',
                        AppColors.green,
                      ),
                      SizedBox(height: 8.h),
                      _buildSummaryRow(
                        Icons.business,
                        'Aktif Isletme',
                        '18 isletme',
                        AppColors.textPrimary,
                      ),
                      SizedBox(height: 8.h),
                      _buildSummaryRow(
                        Icons.location_on,
                        'Merkez Sehir',
                        'Erzurum',
                        AppColors.textPrimary,
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        width: double.infinity,
                        height: 38.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0F2B5B), Color(0xFF061430)],
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFF1E407C)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/profile'),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.analytics,
                                  color: AppColors.textPrimary,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Sirket Raporu',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textPrimary,
                                  size: 18.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 16.sp),
        SizedBox(width: 6.w),
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleGrid() {
    final modules = [
      {'title': 'Magazalar', 'image': 'magazalar.webp'},
      {'title': 'Depolar', 'image': 'depolar.webp'},
      {'title': 'Fabrikalar', 'image': 'fabrikalar.webp'},
      {'title': 'Tarlalar', 'image': 'tarlalar.webp'},
      {'title': 'Ciftlikler', 'image': 'ciftlikler.webp'},
      {'title': 'Madenler', 'image': 'madenler.webp'},
      {'title': 'Nakliye', 'image': 'nakliyeler.webp'},
      {'title': 'AR-GE', 'image': 'arge.webp'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6.w,
        mainAxisSpacing: 6.h,
        childAspectRatio: 0.85,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];

        return Material(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10.r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await _handleModuleTap(module['title'] as String);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64.w,
                    height: 64.h,
                    child: CachedAssetImage(
                      fileName: module['image'] as String,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          module['title'] as String,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.gold,
                        size: 14.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleModuleTap(String moduleTitle) async {
    switch (moduleTitle) {
      case 'Magazalar':
        context.go('/store');
        return;
      case 'Depolar':
        context.go('/warehouses');
        return;
      case 'Tarlalar':
        context.go('/farms');
        return;
      case 'Ciftlikler':
        context.go('/fields');
        return;
      case 'Fabrikalar':
        context.go('/factories');
        return;
      case 'Madenler':
        context.go('/mines');
        return;
      case 'Nakliye':
        final logisticsEntryState = await ref.read(
          logisticsEntryStateProvider.future,
        );
        if (!mounted) return;
        final route =
            logisticsEntryState['route']?.toString() ?? '/logistics/setup';
        context.go(route);
        return;
      case 'AR-GE':
        context.go('/arge');
        return;
    }
  }

  Widget _buildFinancialStats() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFinStatItem(
            'Toplam Gelir',
            '+12.85M',
            'Bugun',
            AppColors.green,
            Icons.payments,
            Colors.green,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Gider',
            '-6.42M',
            'Bugun',
            AppColors.red,
            Icons.account_balance_wallet,
            Colors.red,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Net Kar',
            '+6.43M',
            'Bugun',
            AppColors.green,
            Icons.monetization_on,
            AppColors.gold,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Bekleyen',
            '7',
            'Adet',
            AppColors.gold,
            Icons.hourglass_top,
            AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40.h, width: 1.w, color: AppColors.border);
  }

  Widget _buildFinStatItem(
    String title,
    String value,
    String subtitle,
    Color valueColor,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 18.sp),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(fontSize: 10.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    final notificationsAsync = ref.watch(playerNotificationDashboardProvider);

    return notificationsAsync.when(
      loading: () => _buildDefaultNewsSection(),
      error: (_, _) => _buildDefaultNewsSection(),
      data: (dashboard) {
        if (!dashboard.success || dashboard.notifications.isEmpty) {
          return _buildDefaultNewsSection();
        }

        final items = [...dashboard.notifications]
          ..sort((a, b) {
            final aPriority = _homeNotificationPriority(a);
            final bPriority = _homeNotificationPriority(b);
            if (aPriority != bPriority) {
              return aPriority.compareTo(bPriority);
            }
            return b.createdAt.compareTo(a.createdAt);
          });

        final hasActionable =
            items.any((item) => item.isActiveWarning) ||
            items.any((item) => item.isActiveReminder);

        final cards = items
            .take(5)
            .map((item) => _buildNotificationNewsCard(item))
            .toList();

        return _buildLegacyNewsSection(
          title: hasActionable ? 'Aktif Sorunlar' : 'Bildirimler',
          onHeaderTap: () => context.push('/notifications'),
          trailingText: hasActionable
              ? '${dashboard.activeWarningCount} Sorun'
              : dashboard.unreadCount > 0
                  ? '${dashboard.unreadCount} Yeni'
                  : 'Tumunu Gor',
          trailingColor: hasActionable
              ? Colors.orange
              : dashboard.unreadCount > 0
                  ? AppColors.gold
                  : AppColors.blue,
          cards: cards,
        );
      },
    );
  }

  Widget _buildDefaultNewsSection() => _buildLegacyNewsSection(
    title: 'Guncel Durum',
    cards: [
      _buildNewsCard(
        'Biskuvi fabrikasinda hammadde azaluyor.',
        '15 dk once',
        Icons.cookie,
        Colors.orange,
        Icons.warning_amber_rounded,
        Colors.red,
      ),
      _buildNewsCard(
        '1 nakliye araci teslimata cikti.',
        '35 dk once',
        Icons.local_shipping,
        AppColors.blue,
        Icons.check_circle,
        AppColors.green,
      ),
      _buildNewsCard(
        'Vergi odeme tarihi yaklasiyor.',
        '2 sa once',
        Icons.receipt_long,
        AppColors.gold,
        Icons.warning_amber_rounded,
        Colors.orange,
      ),
    ],
  );

  Widget _buildLegacyNewsSection({
    required String title,
    required List<Widget> cards,
    String trailingText = 'Tumunu Gor',
    Color trailingColor = AppColors.blue,
    VoidCallback? onHeaderTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(Icons.notifications, color: AppColors.gold, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    trailingText,
                    style: TextStyle(color: trailingColor, fontSize: 12.sp),
                  ),
                  Icon(Icons.chevron_right, color: trailingColor, size: 16.sp),
                ],
              ),
            ),
          ),
          Divider(height: 1.h, color: AppColors.border),
          SizedBox(
            height: 84.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              children: cards,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationNewsCard(PlayerNotificationModel notification) {
    final accent = _notificationColor(notification);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/notifications'),
        borderRadius: BorderRadius.circular(8.r),
        child: _buildNewsCard(
          '${_notificationMiniLabel(notification)} • ${notification.title}',
          _relativeTime(notification.createdAt),
          _notificationIcon(notification),
          accent,
          notification.isUnread
              ? Icons.fiber_manual_record
              : notification.isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle,
          notification.isUnread ? accent : accent.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildNewsCard(
    String text,
    String time,
    IconData mainIcon,
    Color mainColor,
    IconData badgeIcon,
    Color badgeColor,
  ) {
    return Container(
      width: 240.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40.w,
            height: 40.h,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(mainIcon, color: mainColor, size: 20.sp),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.cardBgLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, color: badgeColor, size: 14.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.sp,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.textMuted,
                      size: 10.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.gold, size: 18.sp),
        ],
      ),
    );
  }

  String _formatMoney(dynamic amount) {
    final value = double.tryParse(amount.toString()) ?? 0;
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  int _homeNotificationPriority(PlayerNotificationModel item) {
    if (item.isActiveWarning) return 0;
    if (item.isActiveReminder) {
      return 1;
    }
    if (item.isUnread) return 2;
    return 3;
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
      case 'achievement_unlocked':
        return Icons.workspace_premium_rounded;
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

  Color _notificationColor(PlayerNotificationModel item) {
    switch (item.severity) {
      case 'success':
        return AppColors.green;
      case 'warning':
        return Colors.orange;
      default:
        return AppColors.blue;
    }
  }

  String _notificationMiniLabel(PlayerNotificationModel item) {
    if (item.kind == 'warning') return 'Uyari';

    switch (item.category) {
      case 'construction_completed':
        return 'Insaat';
      case 'upgrade_completed':
        return 'Yukseltme';
      case 'transfer_completed':
        return 'Transfer';
      case 'arge_completed':
        return 'AR-GE';
      case 'achievement_unlocked':
        return 'Rozet';
      case 'logistics_attention':
        return 'Nakliye';
      case 'inactive_reminder':
        return 'Hatirlatma';
      default:
        return 'Bilgi';
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
