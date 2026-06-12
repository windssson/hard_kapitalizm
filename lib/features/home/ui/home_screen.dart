import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/app_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/home/models/home_dashboard_model.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';

class _HomeModuleCardData {
  final String title;
  final String image;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final String badgeText;
  final bool hasAlert;
  final Color accentColor;

  const _HomeModuleCardData({
    required this.title,
    required this.image,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.badgeText,
    required this.hasAlert,
    required this.accentColor,
  });
}

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
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(playerMissionDashboardProvider);
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
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 6.h),
                child: Column(
                  children: [
                    _buildCompanySummaryCard(),
                    SizedBox(height: 8.h),
                    _buildMissionHighlightCard(),
                    SizedBox(height: 8.h),
                    _buildModuleGrid(),
                    SizedBox(height: 8.h),
                    _buildFinancialStats(),
                    SizedBox(height: 8.h),
                    _buildOperationsSection(),
                    SizedBox(height: 8.h),
                    _buildAttentionColumns(),
                    SizedBox(height: 16.h),
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
        final dashboard = ref.watch(homeDashboardProvider).value;
        final company = dashboard?.company;
        final dailyProfit = company?.todayProfit ?? 0;
        final activeBusinessCount = company?.activeBusinessCount ?? 0;
        final totalBusinessCount = company?.totalBusinessCount ?? 0;
        final companyValue = company?.companyValue ?? 0;
        final headquarters = company?.headquartersCityName ?? '-';
        final activeBusinessText = totalBusinessCount > 0
            ? '$activeBusinessCount / $totalBusinessCount'
            : '$activeBusinessCount';

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            image: const DecorationImage(
              image: AssetImage('assets/theme/cartback.webp'),
              fit: BoxFit.fill,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF09111D).withValues(alpha: 0.36),
                const Color(0xFF050B14).withValues(alpha: 0.52),
              ],
            ),
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
                    Icon(
                      Icons.apartment_rounded,
                      color: AppColors.gold,
                      size: 16.sp,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'SIRKET OZETI',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'SIRKET DEGERI',
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.18,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'TL${_formatCompactNumber(companyValue)}',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 35,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSummaryStatLine(
                            Icons.trending_up_rounded,
                            'Bugunku Kar:',
                            'TL${_formatCompactNumber(dailyProfit)}',
                            AppColors.green,
                          ),
                          SizedBox(height: 6.h),
                          _buildSummaryStatLine(
                            Icons.account_balance_rounded,
                            'Aktif Isletme:',
                            activeBusinessText,
                            AppColors.goldLight,
                          ),
                          SizedBox(height: 6.h),
                          _buildSummaryStatLine(
                            Icons.place_rounded,
                            'Merkez Sehir:',
                            headquarters,
                            AppColors.goldLight,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      flex: 65,
                      child: SizedBox(
                        height: 104.h,
                        child: _buildCompanySparklinePanel(
                          companyValue: companyValue,
                          dailyProfit: dailyProfit,
                          activeBusinessCount: activeBusinessCount,
                          totalBusinessCount: totalBusinessCount,
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildMissionHighlightCard() {
    return Consumer(
      builder: (context, ref, child) {
        final missionDashboard = ref.watch(playerMissionDashboardProvider);

        return missionDashboard.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (dashboard) {
            final selectedMission = _selectHomeMission(dashboard.allMissions);
            if (!dashboard.success || selectedMission == null) {
              return const SizedBox.shrink();
            }

            final isClaimable = selectedMission.claimable;
            final progress = selectedMission.progressRatio
                .clamp(0.0, 1.0)
                .toDouble();

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/missions'),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    image: const DecorationImage(
                      image: AssetImage('assets/theme/cartback.webp'),
                      fit: BoxFit.fill,
                    ),
                    border: Border.all(
                      color: isClaimable
                          ? AppColors.gold.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0C1624).withValues(alpha: 0.40),
                        const Color(0xFF07111C).withValues(alpha: 0.56),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: (isClaimable ? AppColors.gold : AppColors.blue)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color:
                                (isClaimable ? AppColors.gold : AppColors.blue)
                                    .withValues(alpha: 0.32),
                          ),
                        ),
                        child: Icon(
                          isClaimable
                              ? Icons.workspace_premium_rounded
                              : Icons.flag_rounded,
                          color: isClaimable ? AppColors.gold : AppColors.blue,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedMission.missionTypeLabel,
                              style: TextStyle(
                                color: isClaimable
                                    ? AppColors.gold
                                    : AppColors.textMuted,
                                fontSize: 7.6.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              selectedMission.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            if (isClaimable)
                              Text(
                                selectedMission.compactRewardText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999.r),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 5.h,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.blue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    '${selectedMission.progressCount}/${selectedMission.targetCount} ilerleme',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 7.6.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: isClaimable
                              ? AppColors.gold.withValues(alpha: 0.14)
                              : AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(
                            color: isClaimable
                                ? AppColors.gold.withValues(alpha: 0.35)
                                : AppColors.blue.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          isClaimable
                              ? 'Odulu Al'
                              : '%${(progress * 100).round()}',
                          style: TextStyle(
                            color: isClaimable
                                ? AppColors.gold
                                : AppColors.blue,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  PlayerMissionModel? _selectHomeMission(List<PlayerMissionModel> missions) {
    if (missions.isEmpty) return null;

    final claimable = missions.where((mission) => mission.claimable).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    if (claimable.isNotEmpty) {
      return claimable.first;
    }

    final inProgress =
        missions.where((mission) => mission.isInProgress).toList()
          ..sort((a, b) {
            final progressCompare = b.progressRatio.compareTo(a.progressRatio);
            if (progressCompare != 0) return progressCompare;
            final countCompare = b.progressCount.compareTo(a.progressCount);
            if (countCompare != 0) return countCompare;
            return a.displayOrder.compareTo(b.displayOrder);
          });

    return inProgress.isNotEmpty ? inProgress.first : null;
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

  List<_HomeModuleCardData> _buildModuleCards(
    HomeModulesSummary? modules,
    Set<String> alertedModules,
  ) {
    return [
      _HomeModuleCardData(
        title: 'Magazalar',
        image: 'magazalar.webp',
        accentColor: const Color(0xFF61D26B),
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.stores.activeCount ?? 0}/${modules?.stores.count ?? 0}',
        secondaryLabel: 'Stok',
        secondaryValue: _formatRatio(modules?.stores.stockRatio ?? 0),
        badgeText: (modules?.stores.warningCount ?? 0) > 0
            ? '${modules!.stores.warningCount} uyari'
            : 'Stabil',
        hasAlert:
            alertedModules.contains('stores') ||
            (modules?.stores.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Depolar',
        image: 'depolar.webp',
        accentColor: AppColors.blue,
        primaryLabel: 'Adet',
        primaryValue: '${modules?.warehouses.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.warehouses.capacityRatio ?? 0),
        badgeText: (modules?.warehouses.warningCount ?? 0) > 0
            ? '${modules!.warehouses.warningCount} uyari'
            : 'Hazir',
        hasAlert:
            alertedModules.contains('warehouses') ||
            (modules?.warehouses.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Fabrikalar',
        image: 'fabrikalar.webp',
        accentColor: AppColors.gold,
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.factories.activeCount ?? 0}/${modules?.factories.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.factories.productionRatio ?? 0),
        badgeText: (modules?.factories.blockedCount ?? 0) > 0
            ? '${modules!.factories.blockedCount} sorun'
            : 'Uretimde',
        hasAlert:
            alertedModules.contains('factories') ||
            (modules?.factories.blockedCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Tarlalar',
        image: 'tarlalar.webp',
        accentColor: const Color(0xFF7ED957),
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.farms.activeCount ?? 0}/${modules?.farms.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.farms.productionRatio ?? 0),
        badgeText: (modules?.farms.warningCount ?? 0) > 0
            ? '${modules!.farms.warningCount} uyari'
            : (modules?.farms.count ?? 0) > 0
            ? 'Hasat'
            : 'Bos',
        hasAlert:
            alertedModules.contains('farms') ||
            (modules?.farms.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Ciftlikler',
        image: 'ciftlikler.webp',
        accentColor: const Color(0xFF8ED081),
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.fields.activeCount ?? 0}/${modules?.fields.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.fields.productionRatio ?? 0),
        badgeText: (modules?.fields.warningCount ?? 0) > 0
            ? '${modules!.fields.warningCount} uyari'
            : (modules?.fields.count ?? 0) > 0
            ? 'Calisiyor'
            : 'Bos',
        hasAlert:
            alertedModules.contains('fields') ||
            (modules?.fields.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Madenler',
        image: 'madenler.webp',
        accentColor: const Color(0xFFC8A96B),
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.mines.activeCount ?? 0}/${modules?.mines.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.mines.productionRatio ?? 0),
        badgeText: (modules?.mines.warningCount ?? 0) > 0
            ? '${modules!.mines.warningCount} uyari'
            : (modules?.mines.count ?? 0) > 0
            ? 'Kazida'
            : 'Bos',
        hasAlert:
            alertedModules.contains('mines') ||
            (modules?.mines.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'Nakliye',
        image: 'nakliyeler.webp',
        accentColor: const Color(0xFF64B5F6),
        primaryLabel: 'Arac',
        primaryValue: '${modules?.logistics.vehicleCount ?? 0}',
        secondaryLabel: 'Sefer',
        secondaryValue: '${modules?.logistics.activeTripCount ?? 0}',
        badgeText: (modules?.logistics.warningCount ?? 0) > 0
            ? '${modules!.logistics.warningCount} uyari'
            : 'Akista',
        hasAlert:
            alertedModules.contains('logistics') ||
            (modules?.logistics.warningCount ?? 0) > 0,
      ),
      _HomeModuleCardData(
        title: 'AR-GE',
        image: 'arge.webp',
        accentColor: const Color(0xFF7BA7FF),
        primaryLabel: 'Arastirma',
        primaryValue: '${modules?.arge.activeResearchCount ?? 0}',
        secondaryLabel: 'Kalan',
        secondaryValue: _formatRemainingTime(
          modules?.arge.remainingSeconds ?? 0,
        ),
        badgeText: (modules?.arge.warningCount ?? 0) > 0
            ? '${modules!.arge.warningCount} uyari'
            : (modules?.arge.activeResearchCount ?? 0) > 0
            ? 'Devam ediyor'
            : 'Hazir',
        hasAlert:
            alertedModules.contains('arge') ||
            (modules?.arge.warningCount ?? 0) > 0,
      ),
    ];
  }

  Set<String> _collectAlertedModules(HomeDashboardModel? dashboard) {
    if (dashboard == null) return const <String>{};

    final alertedModules = <String>{};
    for (final item in dashboard.notifications) {
      if (!item.isActiveWarning && !item.isActiveReminder) {
        continue;
      }

      switch (item.entityKind) {
        case 'store':
          alertedModules.add('stores');
          break;
        case 'warehouse':
          alertedModules.add('warehouses');
          break;
        case 'factory':
          alertedModules.add('factories');
          break;
        case 'farm':
          alertedModules.add('farms');
          break;
        case 'field':
          alertedModules.add('fields');
          break;
        case 'mine':
          alertedModules.add('mines');
          break;
        case 'logistics':
          alertedModules.add('logistics');
          break;
        case 'arge':
          alertedModules.add('arge');
          break;
      }
    }

    return alertedModules;
  }

  Widget _buildModuleGrid() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final alertedModules = _collectAlertedModules(dashboard);
        final modules = _buildModuleCards(dashboard?.modules, alertedModules);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.h,
            childAspectRatio: 0.86,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16.r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await _handleModuleTap(module.title);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        image: const DecorationImage(
                          image: AssetImage('assets/theme/cartback.webp'),
                          fit: BoxFit.fill,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF08121D).withValues(alpha: 0.42),
                            const Color(0xFF050D16).withValues(alpha: 0.54),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 10.r,
                            offset: Offset(0, 5.h),
                          ),
                        ],
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.borderGold.withValues(alpha: 0.48),
                          width: 1.1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 4.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: SizedBox(
                                width: 56.w,
                                height: 56.w,
                                child: CachedAssetImage(
                                  fileName: module.image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              module.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            _buildModuleMetricLine(
                              module.primaryLabel,
                              module.primaryValue,
                              module.accentColor,
                            ),
                            SizedBox(height: 1.h),
                            _buildModuleMetricLine(
                              module.secondaryLabel,
                              module.secondaryValue,
                              AppColors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (module.hasAlert)
                      Positioned(
                        top: 6.h,
                        right: 6.w,
                        child: _buildModuleAlertBadge(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModuleMetricLine(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 7.4.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: valueColor,
            fontSize: 8.3.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _formatRatio(double value) {
    final clamped = value.clamp(0, 1);
    return '%${(clamped * 100).round()}';
  }

  String _formatRemainingTime(int seconds) {
    if (seconds <= 0) return '-';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${minutes}dk';
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
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final finance = dashboard?.financeToday;
        final revenue = finance?.revenue ?? 0;
        final productionCost = finance?.productionCost ?? 0;
        final logisticsCost = finance?.logisticsCost ?? 0;
        final netProfit = finance?.netProfit ?? 0;

        return Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            image: const DecorationImage(
              image: AssetImage('assets/theme/cartback.webp'),
              fit: BoxFit.fill,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0C1624).withValues(alpha: 0.42),
                const Color(0xFF07111C).withValues(alpha: 0.58),
              ],
            ),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFinStatItem(
                'Gelir',
                _formatSignedCurrencyCompact(revenue),
                'Bugun',
                AppColors.green,
                Icons.payments_rounded,
                AppColors.green,
              ),
              _buildVerticalDivider(),
              _buildFinStatItem(
                'Uretim',
                _formatSignedCurrencyCompact(-productionCost),
                'Maliyet',
                AppColors.red,
                Icons.precision_manufacturing_rounded,
                Colors.orange,
              ),
              _buildVerticalDivider(),
              _buildFinStatItem(
                'Nakliye',
                _formatSignedCurrencyCompact(-logisticsCost),
                'Gider',
                AppColors.red,
                Icons.local_shipping_rounded,
                AppColors.blue,
              ),
              _buildVerticalDivider(),
              _buildFinStatItem(
                'Net Kar',
                _formatSignedCurrencyCompact(netProfit),
                'Bugun',
                netProfit >= 0 ? AppColors.green : AppColors.red,
                Icons.monetization_on_rounded,
                AppColors.gold,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanySparklinePanel({
    required double companyValue,
    required double dailyProfit,
    required int activeBusinessCount,
    required int totalBusinessCount,
  }) {
    final points = _buildCompanySparklinePoints(
      companyValue: companyValue,
      dailyProfit: dailyProfit,
      activeBusinessCount: activeBusinessCount,
      totalBusinessCount: totalBusinessCount,
    );
    final minPoint = points.reduce((a, b) => a < b ? a : b);
    final maxPoint = points.reduce((a, b) => a > b ? a : b);
    final trendPercent = _calculateSparklineTrend(points);
    final trendPositive = trendPercent >= 0;
    final currentValueEstimate = _estimateSparklineCurrency(
      companyValue: companyValue,
      normalizedPoint: points.last,
    );
    final lowValueEstimate = _estimateSparklineCurrency(
      companyValue: companyValue,
      normalizedPoint: minPoint,
    );
    final highValueEstimate = _estimateSparklineCurrency(
      companyValue: companyValue,
      normalizedPoint: maxPoint,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF102743),
            Color(0xFF081629),
            Color(0xFF050C15),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(9.w, 9.h, 9.w, 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    color: AppColors.gold,
                    size: 10.sp,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  '7 Gunluk Trend',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                    fontSize: 8.6.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: (trendPositive ? AppColors.green : AppColors.red)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: (trendPositive ? AppColors.green : AppColors.red)
                          .withValues(alpha: 0.26),
                    ),
                  ),
                  child: Text(
                    '${trendPositive ? '+' : ''}${trendPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trendPositive ? AppColors.green : AppColors.red,
                      fontSize: 7.6.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5.h),
            Text(
              'Tahmini deger: ${_formatSignedlessCurrencyCompact(currentValueEstimate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.goldLight.withValues(alpha: 0.92),
                fontSize: 7.6.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Expanded(
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: points,
                  lineColor: AppColors.gold,
                  glowColor: AppColors.blue,
                ),
                child: Container(),
              ),
            ),
            SizedBox(height: 7.h),
            Row(
              children: [
                Expanded(
                  child: _buildSparklineMetric(
                    'Dip',
                    _formatSignedlessCurrencyCompact(lowValueEstimate),
                    AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: _buildSparklineMetric(
                    'Bugun',
                    _formatSignedlessCurrencyCompact(currentValueEstimate),
                    AppColors.gold,
                    centered: true,
                  ),
                ),
                Expanded(
                  child: _buildSparklineMetric(
                    'Zirve',
                    _formatSignedlessCurrencyCompact(highValueEstimate),
                    AppColors.blue,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparklineMetric(
    String label,
    String value,
    Color valueColor, {
    bool centered = false,
    bool alignEnd = false,
  }) {
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 6.8.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 7.8.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  double _calculateSparklineTrend(List<double> points) {
    if (points.length < 2 || points.first == 0) {
      return 0;
    }
    return ((points.last - points.first) / points.first) * 100;
  }

  double _estimateSparklineCurrency({
    required double companyValue,
    required double normalizedPoint,
  }) {
    if (companyValue <= 0) {
      return 0;
    }
    final multiplier = 0.92 + (normalizedPoint * 0.2);
    return companyValue * multiplier;
  }

  String _formatSignedlessCurrencyCompact(num value) {
    return '₺${_formatCompactNumber(value)}';
  }

  List<double> _buildCompanySparklinePoints({
    required double companyValue,
    required double dailyProfit,
    required int activeBusinessCount,
    required int totalBusinessCount,
  }) {
    final base = companyValue <= 0 ? 1 : companyValue;
    final momentum = dailyProfit <= 0
        ? 0.02
        : (dailyProfit / base).clamp(0.01, 0.12);
    final activityRatio = totalBusinessCount <= 0
        ? 0.4
        : (activeBusinessCount / totalBusinessCount).clamp(0.15, 1.0);

    return List<double>.generate(7, (index) {
      final progress = index / 6;
      final wave = ((index % 2 == 0 ? 1 : -1) * 0.045) + (progress * momentum);
      final value = 0.28 + (progress * 0.42 * activityRatio) + wave;
      return value.clamp(0.12, 0.95);
    });
  }

  String _formatSignedCurrencyCompact(num value) {
    final prefix = value > 0
        ? '+₺'
        : value < 0
        ? '-₺'
        : '₺';
    return '$prefix${_formatCompactNumber(value.abs())}';
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 38.h,
      width: 1.w,
      color: AppColors.borderGold.withValues(alpha: 0.18),
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: iconColor.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: iconColor, size: 16.sp),
          ),
          SizedBox(height: 5.h),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontSize: 9.sp,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.2.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            subtitle,
            style: AppTextStyles.body.copyWith(
              fontSize: 8.sp,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    final dashboard = ref.watch(homeDashboardProvider).value;
    if (dashboard == null || !dashboard.success) {
      return const SizedBox.shrink();
    }

    final items =
        dashboard.notifications.where((item) => item.isEvent && item.isUnread).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildHomeNotificationSection(
      title: 'Bildirimler',
      onHeaderTap: () => context.push('/notifications'),
      trailingText: '${dashboard.unreadNotificationCount} Yeni',
      trailingColor: AppColors.gold,
      items: items.take(4).toList(),
    );
  }

  Widget _buildModuleAlertBadge() {
    return Container(
      width: 18.w,
      height: 18.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD94134),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD94134).withValues(alpha: 0.35),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    final dashboard = ref.watch(homeDashboardProvider).value;
    if (dashboard == null || !dashboard.success) {
      return const SizedBox.shrink();
    }

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

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildHomeNotificationSection(
      title: 'Uyarilar',
      onHeaderTap: () => context.push('/alerts'),
      trailingText: '${dashboard.activeWarningCount} Sorun',
      trailingColor: Colors.orange,
      headerIcon: Icons.warning_amber_rounded,
      headerIconColor: Colors.orange,
      items: items.take(4).toList(),
    );
  }

  Widget _buildHomeNotificationSection({
    required String title,
    required List<PlayerNotificationModel> items,
    String trailingText = 'Tumunu Gor',
    Color trailingColor = AppColors.blue,
    IconData headerIcon = Icons.notifications,
    Color headerIconColor = AppColors.gold,
    bool compact = false,
    VoidCallback? onHeaderTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        image: const DecorationImage(
          image: AssetImage('assets/theme/cartback.webp'),
          fit: BoxFit.fill,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0C1624).withValues(alpha: 0.42),
            const Color(0xFF07111C).withValues(alpha: 0.58),
          ],
        ),
        border: Border.all(
          color: headerIconColor.withValues(alpha: compact ? 0.22 : 0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12.w : 16.w,
                vertical: compact ? 10.h : 12.h,
              ),
              child: Row(
                children: [
                  Icon(
                    headerIcon,
                    color: headerIconColor,
                    size: compact ? 18.sp : 20.sp,
                  ),
                  SizedBox(width: compact ? 6.w : 8.w),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: compact ? 12.sp : 14.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    trailingText,
                    style: TextStyle(
                      color: trailingColor,
                      fontSize: compact ? 9.sp : 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onHeaderTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: trailingColor,
                      size: compact ? 14.sp : 16.sp,
                    ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1.h,
            color: AppColors.borderGold.withValues(alpha: 0.16),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8.w : 12.w,
              compact ? 8.h : 10.h,
              compact ? 8.w : 12.w,
              compact ? 8.h : 12.h,
            ),
            child: Column(
              children: items
                  .map(
                    (item) => _buildHomeNotificationRow(item, compact: compact),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingActivitiesCard() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final activities =
            dashboard?.ongoingActivities ?? const <HomeOngoingActivity>[];
        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pending_actions_rounded,
                      color: AppColors.gold,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Devam Eden Islemler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ...activities.map(_buildOngoingActivityRow),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperationsSection() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final activities =
            dashboard?.ongoingActivities ?? const <HomeOngoingActivity>[];
        final transfersAsync = ref.watch(buyerTransferMapProvider);

        final sections = <Widget>[];

        if (activities.isNotEmpty) {
          sections.add(_buildOngoingActivitiesCard());
        }

        transfersAsync.whenData((transfers) {
          final activeTransfers = transfers
              .where(
                (item) =>
                    item.status == 'in_transit' || item.status == 'in_progress',
              )
              .toList();
          if (activeTransfers.isNotEmpty) {
            sections.add(_buildActiveTransfersCard());
          }
        });

        if (sections.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) SizedBox(height: 8.h),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActiveTransfersCard() {
    final transfersAsync = ref.watch(buyerTransferMapProvider);

    return transfersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (transfers) {
        final activeTransfers =
            transfers
                .where(
                  (item) =>
                      item.status == 'in_transit' ||
                      item.status == 'in_progress',
                )
                .toList()
              ..sort((a, b) => a.finishAt.compareTo(b.finishAt));

        if (activeTransfers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.push('/transfer-map'),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.gold,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Aktif Transferler',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${activeTransfers.length} Yolda',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gold,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                ...activeTransfers.take(3).map(_buildActiveTransferRow),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTransferRow(TransferMapItemModel transfer) {
    final progress = _transferProgressRatio(transfer);
    final remaining = transfer.finishAt.toLocal().difference(DateTime.now());
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final accent = transfer.isRental ? Colors.orange : AppColors.blue;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/transfer-map'),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    transfer.isRental
                        ? Icons.local_shipping_outlined
                        : Icons.fire_truck_rounded,
                    color: accent,
                    size: 17.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${transfer.sellerWarehouse.city.name} -> ${transfer.buyerWarehouse.city.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11.3.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _formatDuration(safeRemaining),
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${transfer.product.name} • ${transfer.quantity} adet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.6.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999.r),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6.h,
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
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
    );
  }

  double _transferProgressRatio(TransferMapItemModel transfer) {
    final totalMs = transfer.finishAt
        .difference(transfer.startedAt)
        .inMilliseconds;
    if (totalMs <= 0) return 1;
    final elapsedMs = DateTime.now()
        .toUtc()
        .difference(transfer.startedAt.toUtc())
        .inMilliseconds;
    final ratio = elapsedMs / totalMs;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  Widget _buildOngoingActivityRow(HomeOngoingActivity activity) {
    final accent = _activityColor(activity.type);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                _activityIcon(activity.type),
                color: accent,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.6.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _formatDuration(activity.remainingDuration),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    activity.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9.6.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999.r),
                    child: LinearProgressIndicator(
                      value: activity.progressRatio,
                      minHeight: 6.h,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'construction':
        return Icons.construction_rounded;
      case 'upgrade':
        return Icons.trending_up_rounded;
      case 'research':
        return Icons.science_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'construction':
        return Colors.orange;
      case 'upgrade':
        return AppColors.gold;
      case 'research':
        return AppColors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      final hours = duration.inHours % 24;
      return '${duration.inDays}g ${hours}s';
    }
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours}s ${minutes}dk';
    }
    return '${duration.inMinutes}dk';
  }

  Widget _buildAttentionColumns() {
    final dashboard = ref.watch(homeDashboardProvider).value;
    if (dashboard == null || !dashboard.success) {
      return const SizedBox.shrink();
    }

    final notifications =
        dashboard.notifications.where((item) => item.isEvent && item.isUnread).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final alerts =
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

    final hasNotifications = notifications.isNotEmpty;
    final hasAlerts = alerts.isNotEmpty;

    if (!hasNotifications && !hasAlerts) {
      return const SizedBox.shrink();
    }

    if (hasNotifications && hasAlerts) {
      return Column(
        children: [
          _buildHomeNotificationSection(
            title: 'Uyarilar',
            onHeaderTap: () => context.push('/alerts'),
            trailingText: '${dashboard.activeWarningCount} Sorun',
            trailingColor: Colors.orange,
            headerIcon: Icons.warning_amber_rounded,
            headerIconColor: Colors.orange,
            items: alerts.take(3).toList(),
          ),
          SizedBox(height: 8.h),
          _buildHomeNotificationSection(
            title: 'Bildirimler',
            onHeaderTap: () => context.push('/notifications'),
            trailingText: '${dashboard.unreadNotificationCount} Yeni',
            trailingColor: AppColors.gold,
            items: notifications.take(3).toList(),
          ),
        ],
      );
    }

    if (hasAlerts) {
      return _buildHomeNotificationSection(
        title: 'Uyarilar',
        onHeaderTap: () => context.push('/alerts'),
        trailingText: '${dashboard.activeWarningCount} Sorun',
        trailingColor: Colors.orange,
        headerIcon: Icons.warning_amber_rounded,
        headerIconColor: Colors.orange,
        items: alerts.take(4).toList(),
      );
    }

    return _buildHomeNotificationSection(
      title: 'Bildirimler',
      onHeaderTap: () => context.push('/notifications'),
      trailingText: '${dashboard.unreadNotificationCount} Yeni',
      trailingColor: AppColors.gold,
      items: notifications.take(4).toList(),
    );
  }

  Widget _buildHomeNotificationRow(
    PlayerNotificationModel notification, {
    bool compact = false,
  }) {
    final accent = _notificationColor(notification);
    final targetRoute = notification.isEvent
        ? '/notifications'
        : _targetRoute(notification) ?? '/notifications';
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6.h : 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (notification.isUnread) {
              await ref
                  .read(notificationActionProvider)
                  .markRead(notification.id);
            }
            if (!mounted) return;
            context.push(targetRoute);
          },
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8.w : 10.w,
              vertical: compact ? 7.h : 9.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 30.w : 36.w,
                  height: compact ? 30.w : 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    _notificationIcon(notification),
                    color: accent,
                    size: compact ? 15.sp : 18.sp,
                  ),
                ),
                SizedBox(width: compact ? 8.w : 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: compact ? 10.2.sp : 11.3.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 4.w : 6.w),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: compact ? 8.5.sp : 9.6.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 2.h : 3.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 1.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              _notificationMiniLabel(notification),
                              style: TextStyle(
                                color: accent,
                                fontSize: compact ? 7.sp : 8.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (notification.isUnread) ...[
                            SizedBox(width: 5.w),
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        notification.message.isNotEmpty
                            ? notification.message
                            : _notificationMiniLabel(notification),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: compact ? 8.8.sp : 10.sp,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 6.w : 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gold,
                  size: compact ? 14.sp : 16.sp,
                ),
              ],
            ),
          ),
        ),
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

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color glowColor;

  const _SparklinePainter({
    required this.points,
    required this.lineColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    final dxStep = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = dxStep * i;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.24),
          glowColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [glowColor.withValues(alpha: 0.95), lineColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final lastX = size.width;
    final lastY = size.height - (points.last * size.height);
    final pointGlow = Paint()
      ..color = lineColor.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final pointPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(lastX, lastY), 7, pointGlow);
    canvas.drawCircle(Offset(lastX, lastY), 3.2, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.glowColor != glowColor;
  }
}
