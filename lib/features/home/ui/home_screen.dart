import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/app_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/home/models/home_dashboard_model.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';

import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';
import 'package:hard_kapitalizm/features/bank/data/bank_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';

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
  final int requiredLevel;

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
    required this.requiredLevel,
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
  bool _isPromptingCity = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptHeadquartersCity();
    });
  }

  Future<void> _checkAndPromptHeadquartersCity() async {
    if (_isPromptingCity || !mounted) return;
    final player = ref.read(playerProvider).value;
    if (player == null) return;

    if (player.headquartersCityId == null ||
        player.headquartersCityId!.isEmpty) {
      _isPromptingCity = true;
      try {
        final cities = await ref.read(citiesProvider.future);
        if (!mounted || cities.isEmpty) return;

        await _showCitySelectionModal(cities);
      } finally {
        _isPromptingCity = false;
      }
    }
  }

  Future<void> _showCitySelectionModal(List<CityModel> cities) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCities = cities.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q);
            }).toList();

            return PopScope(
              canPop: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.location_city_rounded,
                            color: AppColors.gold,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Holding Merkez Şehrinizi Seçin',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Ticaret imparatorluğunuzun ana merkez üssü (81 İl)',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Şehir ara (81 İl)...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.gold,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgLight,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredCities.length,
                        separatorBuilder: (_, _) => Divider(
                          color: AppColors.border.withValues(alpha: 0.3),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.cardBgLight,
                              radius: 18.r,
                              child: Icon(
                                Icons.apartment_rounded,
                                color: AppColors.gold,
                                size: 18.sp,
                              ),
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                            subtitle: Text(
                              'Nüfus: ${AppMoney.full(city.population, withSymbol: false)}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.sp,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.gold,
                              size: 16.sp,
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await ref
                                  .read(playerProvider.notifier)
                                  .setHeadquartersCity(
                                    city.id,
                                    cityName: city.name,
                                  );
                            },
                          );
                        },
                      ),
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

  @override
  void refreshRouteData() {
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(playerMissionDashboardProvider);
    ref.invalidate(taxDebtProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider, (_, next) {
      if (next.value != null &&
          (next.value!.headquartersCityId == null ||
              next.value!.headquartersCityId!.isEmpty)) {
        _checkAndPromptHeadquartersCity();
      }
    });

    final taxStatus = ref.watch(playerTaxProvider).value;
    final isTaxBlocked = taxStatus?.isBlocked ?? false;

    final scaffold = Scaffold(
      backgroundColor: AppColors.transparent,
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
                    _buildOperationsSection(),

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
                  case 1:
                    context.go('/chat');
                    break;
                  case 2:
                    context.go('/transfer-map');
                    break;
                  case 3:
                    context.go('/market');
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

    if (isTaxBlocked) {
      return Stack(
        children: [scaffold, _buildTaxBlockOverlay(context, taxStatus!)],
      );
    }

    return scaffold;
  }

  Widget _buildTaxBlockOverlay(BuildContext context, PlayerTaxModel taxStatus) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(24.w),
            padding: EdgeInsets.all(24.w),
            decoration: AppDecorations.premiumCard(AppColors.red, 24.r),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.4),
                        width: 2.r,
                      ),
                    ),
                    child: Icon(
                      AppIcons.assuredWorkloadRounded,
                      color: AppColors.red,
                      size: 48.r,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'FİNANSAL BLOKAJ',
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.red,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Birikmiş vergi borcunuz seviyenize göre belirlenen yasal limiti aşmıştır. Borcunuz ödenene kadar şirketinizin üretim faaliyetleri durdurulmuş ve hesabınız kilitlenmiştir.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.border, width: 1.w),
                    ),
                    child: Column(
                      children: [
                        _buildOverlayDetailRow(
                          'Birikmiş Borç:',
                          AppMoney.full(taxStatus.taxDebt, decimals: 0),
                          AppColors.red,
                        ),
                        SizedBox(height: 10.h),
                        _buildOverlayDetailRow(
                          'Yasal Borç Limiti:',
                          AppMoney.full(taxStatus.taxLimit, decimals: 0),
                          AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () {
                      context.push('/tax');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: Size(double.infinity, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.assuredWorkloadRounded,
                          size: 20.r,
                          color: AppColors.textOnAccent,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Vergi Dairesine Git (Borç Öde)',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () {
                      context.push('/bank');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: Size(double.infinity, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.accountBalanceRounded,
                          size: 20.r,
                          color: AppColors.textOnAccent,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Bankaya Git (Kredi / Mevduat)',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  OutlinedButton(
                    onPressed: () {
                      context.push('/store');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border, width: 1.5.w),
                      minimumSize: Size(double.infinity, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.storefront,
                          size: 20.r,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Mağazalarıma Git',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  OutlinedButton(
                    onPressed: () {
                      context.push('/warehouses');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border, width: 1.5.w),
                      minimumSize: Size(double.infinity, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20.r,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Depolarıma Git ',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildOverlayDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySummaryCard() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final hourlyIncome = dashboard?.hourlyIncomeEstimate;
        final company = dashboard?.company;
        final dailyProfit = company?.todayProfit ?? 0;
        final activeBusinessCount = company?.activeBusinessCount ?? 0;
        final totalBusinessCount = company?.totalBusinessCount ?? 0;
        final companyValue = company?.companyValue ?? 0;
        final activeBusinessText = totalBusinessCount > 0
            ? '$activeBusinessCount / $totalBusinessCount'
            : '$activeBusinessCount';

        return Container(
          decoration: AppDecorations.premiumCard(
            AppColors.borderGoldLight.withValues(alpha: 0.55),
            18.r,
          ),
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.apartmentRounded,
                      color: AppColors.gold,
                      size: AppIconSizes.compact,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'ŞİRKET ÖZETİ',
                      style: AppTextStyles.titleGoldBold.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.bodyLarge,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ŞİRKET DEĞERİ',
                      style: AppTextStyles.overline.standardCopyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        fontSize: AppTypography.micro,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.18,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      AppMoney.compact(companyValue),
                      style: AppTextStyles.titleGoldBold.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.body,
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
                            dailyProfit < 0
                                ? AppIcons.trendingDownRounded
                                : AppIcons.trendingUpRounded,
                            dailyProfit < 0 ? 'Bugünkü Zarar:' : 'Bugünkü Kâr:',
                            AppMoney.compact(dailyProfit),
                            dailyProfit < 0
                                ? AppColors.red
                                : dailyProfit > 0
                                ? AppColors.green
                                : AppColors.textPrimary,
                            iconColor: dailyProfit < 0
                                ? AppColors.red
                                : dailyProfit > 0
                                ? AppColors.green
                                : AppColors.gold,
                          ),
                          SizedBox(height: 6.h),
                          _buildSummaryStatLine(
                            AppIcons.accountBalanceRounded,
                            'Aktif İşletme:',
                            activeBusinessText,
                            AppColors.goldLight,
                          ),
                          SizedBox(height: 6.h),
                          _buildSummaryStatLine(
                            AppIcons.paymentsRounded,
                            'Tahmini Saatlik Gelir:',
                            _formatEstimatedHourlyIncome(hourlyIncome?.total),
                            AppColors.green,
                            iconColor: AppColors.green,
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
                          companyValueHistory:
                              company?.companyValueHistory ?? const <double>[],
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
    Color valueColor, {
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? AppColors.gold;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: effectiveIconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: effectiveIconColor.withValues(alpha: 0.28),
            ),
          ),
          child: Icon(
            icon,
            color: effectiveIconColor,
            size: AppIconSizes.xSmall,
          ),
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  color: valueColor,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatEstimatedHourlyIncome(double? value) {
    if (value == null) return 'Hesaplanıyor';
    if (value <= 0) return '0 / saat';
    return '${AppMoney.compact(value)} / saat';
  }

  Widget _buildMissionHighlightCard() {
    return Consumer(
      builder: (context, ref, child) {
        final missionDashboard = ref.watch(playerMissionDashboardProvider);

        return missionDashboard.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (dashboard) {
            final selectedMission = _selectHomeMission(
              dashboard.allMissions
                  .where((mission) => mission.missionType == 'main')
                  .toList(),
            );
            if (!dashboard.success || selectedMission == null) {
              return const SizedBox.shrink();
            }

            final isClaimable = selectedMission.claimable;
            final progress = selectedMission.progressRatio
                .clamp(0.0, 1.0)
                .toDouble();

            final accentColor = isClaimable
                ? AppColors.gold
                : const Color(0xFF00E5FF);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isClaimable
                      ? [
                          const Color(0xFF2C2208),
                          AppColors.cardBg,
                          const Color(0xFF1E1705),
                        ]
                      : [
                          const Color(0xFF0A2238),
                          AppColors.cardBg,
                          const Color(0xFF061524),
                        ],
                ),
                border: Border.all(
                  color: isClaimable
                      ? AppColors.gold.withValues(alpha: 0.65)
                      : AppColors.blue.withValues(alpha: 0.4),
                  width: isClaimable ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isClaimable
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/missions'),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── ÜST ROZETLER (Kategori & Ödül) ──
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.5.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isClaimable
                                            ? AppColors.gold
                                            : AppColors.blue)
                                        .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color:
                                      (isClaimable
                                              ? AppColors.gold
                                              : AppColors.blue)
                                          .withValues(alpha: 0.4),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isClaimable
                                        ? Icons.workspace_premium_rounded
                                        : Icons.flag_rounded,
                                    color: isClaimable
                                        ? AppColors.gold
                                        : AppColors.blue,
                                    size: 11.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    isClaimable
                                        ? 'ÖDÜL HAZIR'
                                        : 'ÖNCELİKLİ GÖREV',
                                    style: TextStyle(
                                      color: isClaimable
                                          ? AppColors.gold
                                          : AppColors.blue,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: AppColors.green.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.card_giftcard_rounded,
                                    color: AppColors.green,
                                    size: 11.sp,
                                  ),
                                  SizedBox(width: 3.5.w),
                                  Text(
                                    selectedMission.compactRewardText,
                                    style: TextStyle(
                                      color: AppColors.green,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),

                        // ── GÖREV İÇERİĞİ VE AKSİYON BUTONU ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sol Görev İkonu (Glow)
                            Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isClaimable
                                      ? [
                                          AppColors.goldLight,
                                          AppColors.goldDark,
                                        ]
                                      : [
                                          const Color(0xFF00E5FF),
                                          const Color(0xFF0D47A1),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isClaimable
                                                ? AppColors.gold
                                                : const Color(0xFF00E5FF))
                                            .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isClaimable
                                      ? Icons.emoji_events_rounded
                                      : Icons.track_changes_rounded,
                                  color: isClaimable
                                      ? AppColors.background
                                      : Colors.white,
                                  size: 20.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),

                            // Orta Başlık ve Açıklama / İlerleme
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedMission.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    selectedMission.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                  if (!isClaimable) ...[
                                    SizedBox(height: 6.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 5.h,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.08),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    accentColor,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          '${selectedMission.progressCount}/${selectedMission.targetCount}',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),

                            // Sağ Aksiyon Butonu / İlerleme Yüzdesi
                            if (isClaimable)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 7.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.gold,
                                      AppColors.goldDark,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.redeem_rounded,
                                      color: AppColors.background,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'ÖDÜLÜ AL',
                                      style: TextStyle(
                                        color: AppColors.background,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppColors.blue.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '%${(progress * 100).round()}',
                                      style: TextStyle(
                                        color: const Color(0xFF00E5FF),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: const Color(0xFF00E5FF),
                                      size: 14.sp,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

  bool _isModuleWorking(_HomeModuleCardData module) {
    if (module.title == 'Fabrikalar' ||
        module.title == 'AR-GE' ||
        module.title == 'Madenler' ||
        module.title == 'Tarlalar' ||
        module.title == 'Çiftlikler' ||
        module.title == 'Ciftlikler') {
      final val = module.primaryValue;
      if (val != '0' && val != '0/0' && !val.startsWith('0/')) {
        return true;
      }
    }
    return false;
  }

  List<_HomeModuleCardData> _buildModuleCards(
    HomeModulesSummary? modules,
    Set<String> alertedModules, {
    required double taxDebt,
    required int openTenders,
    required int activeTenders,
    required BrandCompanyModel? brandCompany,
    required double activeLoanDebt,
    required double activeDepositTotal,
  }) {
    return [
      _HomeModuleCardData(
        title: 'Mağazalar',
        image: 'magazalar.webp',
        accentColor: AppColors.green,
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.stores.activeCount ?? 0}/${modules?.stores.count ?? 0}',
        secondaryLabel: 'Stok',
        secondaryValue: _formatRatio(modules?.stores.stockRatio ?? 0),
        badgeText: (modules?.stores.warningCount ?? 0) > 0
            ? '${modules!.stores.warningCount} uyarı'
            : 'Stabil',
        hasAlert:
            alertedModules.contains('stores') ||
            (modules?.stores.warningCount ?? 0) > 0,
        requiredLevel: 1,
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
            ? '${modules!.warehouses.warningCount} uyarı'
            : 'Hazır',
        hasAlert:
            alertedModules.contains('warehouses') ||
            (modules?.warehouses.warningCount ?? 0) > 0,
        requiredLevel: 1,
      ),
      _HomeModuleCardData(
        title: 'Tarlalar',
        image: 'tarladeneme.webp',
        accentColor: AppColors.green,
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.farms.activeCount ?? 0}/${modules?.farms.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.farms.productionRatio ?? 0),
        badgeText: (modules?.farms.warningCount ?? 0) > 0
            ? '${modules!.farms.warningCount} uyarı'
            : (modules?.farms.count ?? 0) > 0
            ? 'Hasat'
            : 'Boş',
        hasAlert:
            alertedModules.contains('farms') ||
            (modules?.farms.warningCount ?? 0) > 0,
        requiredLevel: 2,
      ),
      _HomeModuleCardData(
        title: 'Nakliye',
        image: 'nakliyeler.webp',
        accentColor: AppColors.info,
        primaryLabel: 'Araç',
        primaryValue: '${modules?.logistics.vehicleCount ?? 0}',
        secondaryLabel: 'Sefer',
        secondaryValue: '${modules?.logistics.activeTripCount ?? 0}',
        badgeText: (modules?.logistics.warningCount ?? 0) > 0
            ? '${modules!.logistics.warningCount} uyarı'
            : 'Akışta',
        hasAlert:
            alertedModules.contains('logistics') ||
            (modules?.logistics.warningCount ?? 0) > 0,
        requiredLevel: 3,
      ),
      _HomeModuleCardData(
        title: 'Çiftlikler',
        image: 'ciftlikler.webp',
        accentColor: AppColors.green,
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.fields.activeCount ?? 0}/${modules?.fields.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.fields.productionRatio ?? 0),
        badgeText: (modules?.fields.warningCount ?? 0) > 0
            ? '${modules!.fields.warningCount} uyarı'
            : (modules?.fields.count ?? 0) > 0
            ? 'Çalışıyor'
            : 'Boş',
        hasAlert:
            alertedModules.contains('fields') ||
            (modules?.fields.warningCount ?? 0) > 0,
        requiredLevel: 4,
      ),
      _HomeModuleCardData(
        title: 'AR-GE',
        image: 'arge.webp',
        accentColor: AppColors.info,
        primaryLabel: 'Araştırma',
        primaryValue: '${modules?.arge.activeResearchCount ?? 0}',
        secondaryLabel: 'Kalan',
        secondaryValue: _formatRemainingTime(
          modules?.arge.remainingSeconds ?? 0,
        ),
        badgeText: (modules?.arge.warningCount ?? 0) > 0
            ? '${modules!.arge.warningCount} uyarı'
            : (modules?.arge.activeResearchCount ?? 0) > 0
            ? 'Devam ediyor'
            : 'Hazır',
        hasAlert:
            alertedModules.contains('arge') ||
            (modules?.arge.warningCount ?? 0) > 0,
        requiredLevel: 5,
      ),
      _HomeModuleCardData(
        title: 'Banka',
        image: 'banka.webp',
        accentColor: activeLoanDebt > 0 ? AppColors.red : AppColors.gold,
        primaryLabel: 'Kredi',
        primaryValue: activeLoanDebt > 0
            ? AppMoney.compact(activeLoanDebt)
            : 'Yok',
        secondaryLabel: 'Mevduat',
        secondaryValue: activeDepositTotal > 0
            ? AppMoney.compact(activeDepositTotal)
            : 'Yok',
        badgeText: activeLoanDebt > 0
            ? 'Borç var'
            : (activeDepositTotal > 0 ? 'Mevduat' : 'Boş'),
        hasAlert: activeLoanDebt > 0,
        requiredLevel: 6,
      ),
      _HomeModuleCardData(
        title: 'Vergi',
        image: 'vergi.webp',
        accentColor: taxDebt > 0 ? AppColors.red : AppColors.gold,
        primaryLabel: 'Borç',
        primaryValue: taxDebt > 0 ? AppMoney.compact(taxDebt) : '0',
        secondaryLabel: 'Durum',
        secondaryValue: taxDebt > 0 ? 'Ödenmemiş' : 'Temiz',
        badgeText: taxDebt > 0 ? 'Borç var' : 'Stabil',
        hasAlert: taxDebt > 0,
        requiredLevel: 7,
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
            : 'Üretimde',
        hasAlert:
            alertedModules.contains('factories') ||
            (modules?.factories.blockedCount ?? 0) > 0,
        requiredLevel: 8,
      ),
      _HomeModuleCardData(
        title: 'İhale',
        image: 'ihale.webp',
        accentColor: openTenders > 0 ? AppColors.gold : AppColors.blue,
        primaryLabel: 'Açık',
        primaryValue: '$openTenders',
        secondaryLabel: 'Aktif',
        secondaryValue: '$activeTenders',
        badgeText: activeTenders > 0
            ? 'Aktif'
            : (openTenders > 0 ? 'Açık' : 'Yok'),
        hasAlert: alertedModules.contains('tenders'),
        requiredLevel: 10,
      ),
      _HomeModuleCardData(
        title: 'Marka',
        image: brandCompany != null ? brandCompany.logoId : 'marka.webp',
        accentColor: AppColors.diamond,
        primaryLabel: 'Seviye',
        primaryValue: brandCompany != null ? '${brandCompany.brandLevel}' : '1',
        secondaryLabel: 'XP',
        secondaryValue: brandCompany != null ? '${brandCompany.brandXp}' : '0',
        badgeText: brandCompany != null
            ? 'Sv. ${brandCompany.brandLevel}'
            : 'Sv. 1',
        hasAlert: false,
        requiredLevel: 12,
      ),
      _HomeModuleCardData(
        title: 'Madenler',
        image: 'madenler.webp',
        accentColor: AppColors.warning,
        primaryLabel: 'Aktif',
        primaryValue:
            '${modules?.mines.activeCount ?? 0}/${modules?.mines.count ?? 0}',
        secondaryLabel: 'Doluluk',
        secondaryValue: _formatRatio(modules?.mines.productionRatio ?? 0),
        badgeText: (modules?.mines.warningCount ?? 0) > 0
            ? '${modules!.mines.warningCount} uyari'
            : (modules?.mines.count ?? 0) > 0
            ? 'Kazida'
            : 'Boş',
        hasAlert:
            alertedModules.contains('mines') ||
            (modules?.mines.warningCount ?? 0) > 0,
        requiredLevel: 15,
      ),
    ];
  }

  Set<String> _collectAlertedModules(HomeDashboardModel? dashboard) {
    if (dashboard == null) return const <String>{};

    final alertedModules = <String>{};
    final m = dashboard.modules;
    if (m.stores.warningCount > 0) alertedModules.add('stores');
    if (m.warehouses.warningCount > 0) alertedModules.add('warehouses');
    if (m.factories.blockedCount > 0) alertedModules.add('factories');
    if (m.fields.warningCount > 0) alertedModules.add('fields');
    if (m.farms.warningCount > 0) alertedModules.add('farms');
    if (m.mines.warningCount > 0) alertedModules.add('mines');
    if (m.logistics.warningCount > 0) alertedModules.add('logistics');
    if (m.arge.warningCount > 0) alertedModules.add('arge');

    return alertedModules;
  }

  Widget _buildModuleGrid() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final tutorial = ref.watch(tutorialProvider);
        if (dashboard != null && tutorial.isLoaded) {
          final isBrandNewPlayer =
              dashboard.player.level == 1 &&
              dashboard.player.currentLevelExperience == 0 &&
              dashboard.modules.stores.count == 0;

          if (!tutorial.hasSeenTutorial) {
            if (isBrandNewPlayer) {
              if (!tutorial.isPaused && tutorial.step == TutorialStep.none) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(tutorialProvider.notifier).startTutorial();
                });
              }
            } else {
              // Seviyesi > 1 veya EXP > 0 olan mevcut oyuncular için rehberi otomatik tamamla
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(tutorialProvider.notifier).finishTutorial();
              });
            }
          }
        }
        final alertedModules = _collectAlertedModules(dashboard);

        final taxDebt = ref.watch(taxDebtProvider).value ?? 0.0;

        final tenderCenter = ref.watch(tenderCenterProvider).value;
        final openTenders = tenderCenter?.openTenders.length ?? 0;
        final activeTenders = tenderCenter?.myActiveTenders.length ?? 0;

        final brandCompany = ref.watch(playerBrandCompanyProvider).value;

        final loansAsync = ref.watch(playerLoansProvider).value;
        final depositsAsync = ref.watch(playerDepositsProvider).value;

        final activeLoans =
            loansAsync?.where((l) => l.status != 'paid').toList() ?? [];
        final activeLoanDebt = activeLoans.fold<double>(
          0,
          (sum, l) => sum + (l.totalDue - l.totalPaid),
        );

        final activeDeposits =
            depositsAsync?.where((d) => d.status == 'active').toList() ?? [];
        final activeDepositTotal = activeDeposits.fold<double>(
          0,
          (sum, d) => sum + d.amount,
        );

        final modules = _buildModuleCards(
          dashboard?.modules,
          alertedModules,
          taxDebt: taxDebt,
          openTenders: openTenders,
          activeTenders: activeTenders,
          brandCompany: brandCompany,
          activeLoanDebt: activeLoanDebt,
          activeDepositTotal: activeDepositTotal,
        );

        final playerLevel =
            dashboard?.player.level ??
            ref.watch(playerProvider).value?.level ??
            1;

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
            final isLocked = playerLevel < module.requiredLevel;
            final isWorking = !isLocked && _isModuleWorking(module);

            final isStoreModuleTutorialTarget =
                (module.title == 'Mağazalar' || module.title == 'Magazalar') &&
                (ref.watch(tutorialProvider).step ==
                        TutorialStep.clickFirstStore ||
                    ref.watch(tutorialProvider).step ==
                        TutorialStep.returnToStoresModule);

            return Material(
              key: isStoreModuleTutorialTarget
                  ? TutorialKeys.homeStoresModuleKey
                  : null,
              color: AppColors.transparent,
              borderRadius: BorderRadius.circular(16.r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isLocked
                    ? null
                    : () async {
                        await _handleModuleTap(module.title);
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _PulsingModuleContainer(
                      color: module.accentColor,
                      isLocked: isLocked,
                      hasAlert: module.hasAlert,
                      gradient: isLocked
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.cardBg,
                                module.accentColor.withValues(alpha: 0.08),
                              ],
                            ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(1.w, 2.h, 1.w, 2.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: SizedBox(
                                width: 60.w,
                                height: 58.w,
                                child: isLocked
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                              Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                              BlendMode.srcATop,
                                            ),
                                            child: Opacity(
                                              opacity: 0.35,
                                              child: CachedAssetImage(
                                                fileName: module.image,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            AppIcons.lock,
                                            color: AppColors.textMuted
                                                .withValues(alpha: 0.85),
                                            size: 20.r,
                                          ),
                                        ],
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CachedAssetImage(
                                            fileName: module.image,
                                            fit: BoxFit.contain,
                                          ),
                                          if (isWorking)
                                            Positioned(
                                              top: 2.h,
                                              right: 2.w,
                                              child: _WorkingIndicator(
                                                icon: Icons.settings_rounded,
                                                color: module.accentColor,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              module.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.standardCopyWith(
                                color: isLocked
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            if (isLocked) ...[
                              SizedBox(height: 6.h),
                              Text(
                                _getUnlockText(module.requiredLevel),
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.micro,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ] else ...[
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
                          ],
                        ),
                      ),
                    ),
                    if (module.hasAlert && !isLocked)
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

  String _getUnlockText(int requiredLevel) {
    switch (requiredLevel) {
      case 1:
        return 'Seviye 1\'de';
      case 2:
        return 'Seviye 2\'de';
      case 3:
        return 'Seviye 3\'te';
      case 4:
        return 'Seviye 4\'te';
      case 5:
        return 'Seviye 5\'te';
      case 6:
        return 'Seviye 6\'da';
      case 7:
        return 'Seviye 7\'de';
      case 8:
        return 'Seviye 8\'de';
      case 10:
        return 'Seviye 10\'da';
      case 12:
        return 'Seviye 12\'de';
      case 13:
        return 'Seviye 13\'te';
      case 15:
        return 'Seviye 15\'te';
      default:
        return 'Seviye $requiredLevel\'de';
    }
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
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.micro,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.standardCopyWith(
            color: valueColor,
            fontSize: AppTypography.micro,
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
    if (moduleTitle == 'Mağazalar' || moduleTitle == 'Magazalar') {
      if (ref.read(tutorialProvider).step == TutorialStep.clickFirstStore) {
        ref
            .read(tutorialProvider.notifier)
            .completeStep(TutorialStep.clickFirstStore);
      } else if (ref.read(tutorialProvider).step ==
          TutorialStep.returnToStoresModule) {
        ref
            .read(tutorialProvider.notifier)
            .setStep(TutorialStep.returnToStoreDetail);
      }
    }
    switch (moduleTitle) {
      case 'Mağazalar':
      case 'Magazalar':
        context.go('/store');
        return;
      case 'Depolar':
        context.go('/warehouses');
        return;
      case 'Tarlalar':
        context.go('/farms');
        return;
      case 'Çiftlikler':
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
      case 'Vergi':
        context.push('/tax');
        return;
      case 'Banka':
        context.push('/bank');
        return;
      case 'İhale':
      case 'Ihale':
        context.push('/tenders');
        return;
      case 'Marka':
        context.push('/company');
        return;
    }
  }

  List<double> _normalizeCompanyValues(List<double> values) {
    if (values.length < 2) return const <double>[];
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    if (min == max) {
      return List<double>.filled(values.length, 0.5);
    }
    return values.map((val) {
      final norm = (val - min) / (max - min);
      return 0.15 + (norm * 0.70);
    }).toList();
  }

  Widget _buildCompanySparklinePanel({
    required List<double> companyValueHistory,
    required double companyValue,
    required double dailyProfit,
    required int activeBusinessCount,
    required int totalBusinessCount,
  }) {
    final List<double> points;
    final double currentValueEstimate;
    final double lowValueEstimate;
    final double highValueEstimate;
    final double trendPercent;

    if (companyValueHistory.length >= 2) {
      points = _normalizeCompanyValues(companyValueHistory);
      currentValueEstimate = companyValueHistory.last;
      lowValueEstimate = companyValueHistory.reduce((a, b) => a < b ? a : b);
      highValueEstimate = companyValueHistory.reduce((a, b) => a > b ? a : b);
      trendPercent = _calculateSparklineTrend(companyValueHistory);
    } else {
      final mockPoints = _buildCompanySparklinePoints(
        companyValue: companyValue,
        dailyProfit: dailyProfit,
        activeBusinessCount: activeBusinessCount,
        totalBusinessCount: totalBusinessCount,
      );
      points = mockPoints;
      currentValueEstimate = _estimateSparklineCurrency(
        companyValue: companyValue,
        normalizedPoint: mockPoints.last,
      );
      lowValueEstimate = _estimateSparklineCurrency(
        companyValue: companyValue,
        normalizedPoint: mockPoints.reduce((a, b) => a < b ? a : b),
      );
      highValueEstimate = _estimateSparklineCurrency(
        companyValue: companyValue,
        normalizedPoint: mockPoints.reduce((a, b) => a > b ? a : b),
      );
      trendPercent = _calculateSparklineTrend(mockPoints);
    }

    final trendPositive = trendPercent >= 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: AppColors.transparent,
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
                    AppIcons.showChartRounded,
                    color: AppColors.gold,
                    size: AppIconSizes.xxSmall,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  '7 Günlük Trend',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                    fontSize: AppTypography.micro,
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
                    style: AppTextStyles.caption.standardCopyWith(
                      color: trendPositive ? AppColors.green : AppColors.red,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5.h),
            Text(
              companyValueHistory.length >= 2
                  ? 'Güncel Değer: ${AppMoney.compact(currentValueEstimate)}'
                  : 'Tahmini Değer: ${AppMoney.compact(currentValueEstimate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.goldLight.withValues(alpha: 0.92),
                fontSize: AppTypography.micro,
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
                    AppMoney.compact(lowValueEstimate),
                    AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: _buildSparklineMetric(
                    'Bugün',
                    AppMoney.compact(currentValueEstimate),
                    AppColors.gold,
                    centered: true,
                  ),
                ),
                Expanded(
                  child: _buildSparklineMetric(
                    'Zirve',
                    AppMoney.compact(highValueEstimate),
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
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.micro,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.standardCopyWith(
            color: valueColor,
            fontSize: AppTypography.micro,
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

  Widget _buildModuleAlertBadge() {
    return Container(
      width: 18.w,
      height: 18.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.red,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.35),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '!',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.label,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }



  Widget _buildOperationsSection() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboard = ref.watch(homeDashboardProvider).value;
        final activities =
            dashboard?.ongoingActivities ?? const <HomeOngoingActivity>[];
        final productions =
            dashboard?.activeProductions ?? const <HomeActiveProduction>[];

        if (activities.isEmpty && productions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildOngoingActivitiesCard(activities),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActiveProductionsCard(productions),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOngoingActivitiesCard(List<HomeOngoingActivity> activities) {
    return Container(
      decoration: AppDecorations.premiumCard(
        AppColors.borderGold.withValues(alpha: 0.34),
        12.r,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    AppIcons.pendingActionsRounded,
                    color: AppColors.gold,
                    size: 13.sp,
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    'İŞLEMLER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: activities.isNotEmpty
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${activities.length}',
                    style: TextStyle(
                      color: activities.isNotEmpty
                          ? AppColors.goldLight
                          : AppColors.textMuted,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (activities.isEmpty)
              Container(
                height: 88.h,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.checkCircleRounded,
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      size: 20.sp,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'İşlem Yok',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...activities.take(3).map(_buildCompactOngoingActivityRow),
                  if (activities.length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        '+${activities.length - 3} işlem daha',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOngoingActivityRow(HomeOngoingActivity activity) {
    final accent = _activityColor(activity.type);
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () {
            if (activity.type == 'logistics' || activity.type == 'transfer') {
              context.push('/transfer-map');
            } else if (activity.type == 'research') {
              context.push('/arge');
            }
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: accent.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _activityIcon(activity.type),
                      color: accent,
                      size: 11.sp,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _formatDuration(activity.remainingDuration),
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999.r),
                  child: AppProgressBar(
                    value: activity.progressRatio,
                    minHeight: 3.5.h,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveProductionsCard(List<HomeActiveProduction> productions) {
    return Container(
      decoration: AppDecorations.premiumCard(
        AppColors.borderGold.withValues(alpha: 0.34),
        12.r,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Icon(
                    AppIcons.precisionManufacturingRounded,
                    color: AppColors.gold,
                    size: 13.sp,
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    'ÜRETİMLER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: productions.isNotEmpty
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${productions.length}',
                    style: TextStyle(
                      color: productions.isNotEmpty
                          ? AppColors.goldLight
                          : AppColors.textMuted,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (productions.isEmpty)
              Container(
                height: 88.h,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.precisionManufacturingRounded,
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      size: 20.sp,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Üretim Yok',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...productions.take(3).map(_buildCompactProductionItem),
                  if (productions.length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        '+${productions.length - 3} ürün daha',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactProductionItem(HomeActiveProduction production) {
    final kindInfo = _productionKindInfo(production.ownerKind);

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () {
            context.go(kindInfo.route);
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: kindInfo.color.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.r),
                  child: Container(
                    width: 22.w,
                    height: 22.w,
                    padding: EdgeInsets.all(1.5.w),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: CachedAssetImage(
                      fileName: production.productIcon,
                      width: 19.w,
                      height: 19.w,
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        AppIcons.inventory2Rounded,
                        size: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        production.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: kindInfo.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                            child: Text(
                              kindInfo.label,
                              style: TextStyle(
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w700,
                                color: kindInfo.color,
                              ),
                            ),
                          ),
                          if (production.qualityLevel > 1) ...[
                            SizedBox(width: 3.w),
                            Text(
                              'Q${production.qualityLevel}',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  '${production.activeSlots} ${production.ownerKind == 'factory' ? 'Hat' : 'Slot'}',
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String label, String route, Color color}) _productionKindInfo(
    String ownerKind,
  ) {
    switch (ownerKind) {
      case 'factory':
        return (label: 'Fabrika', route: '/factories', color: AppColors.gold);
      case 'farm':
        return (label: 'Tarla', route: '/farms', color: AppColors.green);
      case 'field':
        return (label: 'Çiftlik', route: '/fields', color: AppColors.warning);
      case 'mine':
        return (label: 'Maden', route: '/mines', color: AppColors.diamond);
      default:
        return (label: 'Tesis', route: '/home', color: AppColors.textSecondary);
    }
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'construction':
        return AppIcons.constructionRounded;
      case 'upgrade':
        return AppIcons.trendingUpRounded;
      case 'research':
        return AppIcons.scienceRounded;
      case 'logistics':
      case 'transfer':
        return AppIcons.localShippingRounded;
      default:
        return AppIcons.pendingActionsRounded;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'construction':
        return AppColors.warning;
      case 'upgrade':
        return AppColors.gold;
      case 'research':
        return AppColors.blue;
      case 'logistics':
      case 'transfer':
        return AppColors.success;
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
      ..color = AppFx.softOverlay(0.06)
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
          AppColors.transparent,
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

class _PulsingModuleContainer extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool isLocked;
  final bool hasAlert;
  final Gradient? gradient;

  const _PulsingModuleContainer({
    required this.child,
    required this.color,
    required this.isLocked,
    required this.hasAlert,
    this.gradient,
  });

  @override
  State<_PulsingModuleContainer> createState() =>
      _PulsingModuleContainerState();
}

class _PulsingModuleContainerState extends State<_PulsingModuleContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.hasAlert && !widget.isLocked) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingModuleContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasAlert && !widget.isLocked && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if ((!widget.hasAlert || widget.isLocked) &&
        _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double radiusValue = 16.r;
    final radius = BorderRadius.circular(radiusValue);

    if (widget.isLocked) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.16),
            width: 1.w,
          ),
        ),
        child: widget.child,
      );
    }

    if (!widget.hasAlert) {
      return Container(
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.48),
            width: 1.2.w,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.05),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: radius,
            border: Border.all(
              color: AppColors.red.withValues(
                alpha: 0.25 + (_animation.value * 0.35),
              ),
              width: 1.4.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(
                  alpha: 0.04 + (_animation.value * 0.12),
                ),
                blurRadius: 8.r + (_animation.value * 8.r),
                spreadRadius: _animation.value * 1.w,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _WorkingIndicator extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _WorkingIndicator({required this.icon, required this.color});

  @override
  State<_WorkingIndicator> createState() => _WorkingIndicatorState();
}

class _WorkingIndicatorState extends State<_WorkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        widget.icon,
        color: widget.color.withValues(alpha: 0.55),
        size: 13.sp,
      ),
    );
  }
}
