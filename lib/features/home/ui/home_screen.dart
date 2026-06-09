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
                    _buildAlertsSection(),
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
        const mockDailyProfit = 18200;
        const mockActiveBusinessCount = 18;
        const mockCompanyValue = 12450000;
        const mockHeadquarters = 'Erzurum';

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF09111D),
                AppColors.cardBg,
                const Color(0xFF050B14),
              ],
            ),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.borderGoldLight.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 14.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        color: AppColors.gold,
                        size: 13.sp,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'SIRKET OZETI',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.borderGold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSummaryStatLine(
                              Icons.trending_up_rounded,
                              'Bugunku Kar:',
                              '₺${_formatCompactNumber(mockDailyProfit)} ▲',
                              AppColors.green,
                            ),
                            SizedBox(height: 6.h),
                            _buildSummaryStatLine(
                              Icons.account_balance_rounded,
                              'Aktif Isletme:',
                              '$mockActiveBusinessCount',
                              AppColors.goldLight,
                            ),
                            SizedBox(height: 6.h),
                            _buildSummaryStatLine(
                              Icons.place_rounded,
                              'Merkez Sehir:',
                              mockHeadquarters,
                              AppColors.goldLight,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        flex: 32,
                        child: SizedBox(
                          height: 88.h,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF102743),
                                  const Color(0xFF081629),
                                  const Color(0xFF050C15),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 10.w,
                                  right: 10.w,
                                  bottom: 8.h,
                                  child: Container(
                                    height: 2.h,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.gold.withValues(alpha: 0.7),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 6.h,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(6, (index) {
                                        final heights = [
                                          22.h,
                                          38.h,
                                          30.h,
                                          50.h,
                                          44.h,
                                          34.h,
                                        ];
                                        final widths = [
                                          10.w,
                                          12.w,
                                          10.w,
                                          13.w,
                                          11.w,
                                          10.w,
                                        ];
                                        final glow = index.isEven
                                            ? AppColors.blue
                                            : AppColors.gold;
                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 1.5.w,
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: widths[index],
                                              height: heights[index],
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4.r),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    glow.withValues(alpha: 0.9),
                                                    const Color(0xFF13263E),
                                                    const Color(0xFF07111D),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: glow.withValues(
                                                      alpha: 0.28,
                                                    ),
                                                    blurRadius: 5.r,
                                                    spreadRadius: 0.2.r,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        flex: 26,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SIRKET DEGERI',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.92,
                                ),
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              '₺${_formatCompactNumber(mockCompanyValue)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 46.w,
                                height: 46.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.gold.withValues(alpha: 0.26),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Container(
                                  margin: EdgeInsets.all(4.w),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF08111B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.7,
                                      ),
                                      width: 1.2.w,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        color: AppColors.goldLight,
                                        size: 8.sp,
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        player
                                                ?.companyName
                                                .characters
                                                .firstOrNull
                                                ?.toUpperCase() ??
                                            'A',
                                        style: TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF103417),
                                    const Color(0xFF0A2310),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999.r),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.green,
                                    size: 10.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'ISTIKRARLI',
                                    style: TextStyle(
                                      color: AppColors.green,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  height: 26.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF14396D), Color(0xFF09172F)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFF1E407C)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/profile'),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: AppColors.textPrimary,
                            size: 13.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Sirket Raporu',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textPrimary,
                            size: 14.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatLine(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 11.sp),
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCompactNumber(num value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
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
        childAspectRatio: 0.8,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18.r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await _handleModuleTap(module['title'] as String);
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF06101C),
                borderRadius: BorderRadius.circular(18.r),
                image: const DecorationImage(
                  image: AssetImage('assets/theme/module_icon_frame_01.webp'),
                  fit: BoxFit.fill,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12.r,
                    offset: Offset(0, 6.h),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(9.w, 12.h, 9.w, 8.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 54.w,
                        height: 54.h,
                        child: module['image'] != null
                            ? CachedAssetImage(
                                fileName: module['image'] as String,
                                fit: BoxFit.contain,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: AppColors.cardBgLight.withValues(
                                    alpha: 0.72,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderGold.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  module['icon'] as IconData,
                                  color: AppColors.gold,
                                  size: 25.sp,
                                ),
                              ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              module['title'] as String,
                              maxLines: 1,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10.2.sp,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 4.r,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.gold,
                            size: 12.sp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (dashboard) {
        final items =
            dashboard.notifications
                .where((item) => item.isEvent && item.isUnread)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!dashboard.success || items.isEmpty) {
          return const SizedBox.shrink();
        }

        final cards = items
            .take(5)
            .map((item) => _buildNotificationNewsCard(item))
            .toList();

        return _buildLegacyNewsSection(
          title: 'Bildirimler',
          onHeaderTap: () => context.push('/notifications'),
          trailingText: '${items.length} Yeni',
          trailingColor: items.isNotEmpty ? AppColors.gold : AppColors.blue,
          cards: cards,
        );
      },
    );
  }

  Widget _buildAlertsSection() {
    final notificationsAsync = ref.watch(playerNotificationDashboardProvider);

    return notificationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (dashboard) {
        final items =
            dashboard.notifications
                .where((item) => item.isActiveWarning || item.isActiveReminder)
                .toList()
              ..sort((a, b) {
                final aPriority = _homeNotificationPriority(a);
                final bPriority = _homeNotificationPriority(b);
                if (aPriority != bPriority) {
                  return aPriority.compareTo(bPriority);
                }
                return b.createdAt.compareTo(a.createdAt);
              });

        if (!dashboard.success || items.isEmpty) {
          return const SizedBox.shrink();
        }

        final cards = items
            .take(5)
            .map((item) => _buildNotificationNewsCard(item))
            .toList();

        return _buildLegacyNewsSection(
          title: 'Uyarilar',
          onHeaderTap: () => context.push('/alerts'),
          trailingText: '${items.length} Sorun',
          trailingColor: Colors.orange,
          headerIcon: Icons.warning_amber_rounded,
          headerIconColor: Colors.orange,
          cards: cards,
        );
      },
    );
  }

  Widget _buildLegacyNewsSection({
    required String title,
    required List<Widget> cards,
    String trailingText = 'Tumunu Gor',
    Color trailingColor = AppColors.blue,
    IconData headerIcon = Icons.notifications,
    Color headerIconColor = AppColors.gold,
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
                  Icon(headerIcon, color: headerIconColor, size: 20.sp),
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
                  if (onHeaderTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: trailingColor,
                      size: 16.sp,
                    ),
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
    final targetRoute = notification.isEvent
        ? '/notifications'
        : _targetRoute(notification) ?? '/notifications';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(targetRoute),
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

  int _homeNotificationPriority(PlayerNotificationModel item) {
    if (item.isActiveWarning) return 0;
    if (item.isActiveReminder) {
      return 1;
    }
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

    if (notification.category == 'achievement_unlocked') {
      return '/achievements';
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
