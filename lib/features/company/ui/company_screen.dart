import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_design_options.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final TextEditingController _brandNameController = TextEditingController();
  bool _isSubmitting = false;

  // Custom brand selections for setup state
  String _selectedLogo = defaultBrandLogoId;
  String _selectedColor = '#E5C05C';

  // Sub-tab inside brand management state
  // 0: Patentler & Ürünler, 1: Pazarlama
  int _selectedTab = 0;

  @override
  void dispose() {
    _brandNameController.dispose();
    super.dispose();
  }

  void _onNavSelected(int index) {
    if (index == 1) return;
    switch (index) {
      case 0:
        context.go('/home');
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
  }

  int getXpRequiredForNextLevel(int currentLevel) {
    switch (currentLevel) {
      case 1:
        return 1000;
      case 2:
        return 5000;
      case 3:
        return 15000;
      case 4:
        return 40000;
      default:
        return 40000;
    }
  }

  int getXpBaseForLevel(int currentLevel) {
    switch (currentLevel) {
      case 1:
        return 0;
      case 2:
        return 1000;
      case 3:
        return 5000;
      case 4:
        return 15000;
      default:
        return 40000;
    }
  }

  Color _parseHexColor(String hex, {Color? fallback}) {
    try {
      var hexColor = hex.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (_) {}
    return fallback ?? AppColors.gold;
  }

  Future<void> _createCompany() async {
    final brandName = _brandNameController.text.trim();
    if (brandName.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Marka adı boş olamaz.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(companyActionProvider)
        .createBrandCompany(
          brandName: brandName,
          logoId: _selectedLogo,
          themeColor: _selectedColor,
        );
    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: result['success'] == true ? 'Başarılı' : 'Hata',
      message: (result['message'] ?? 'İşlem tamamlanamadı.').toString(),
      type: result['success'] == true
          ? SnackbarType.success
          : SnackbarType.error,
    );
  }

  Future<void> _patentProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Ürün Patentleme',
          style: AppTextStyles.h2.standardCopyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Bu ürünü markanız altına tescil etmek istiyor musunuz?\n\n'
          'Maliyet: 50.000 ₺',
          style: AppTextStyles.body.standardCopyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: AppTextStyles.button.standardCopyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: Text(
              'Patent Al',
              style: AppTextStyles.button.standardCopyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ref
        .read(companyActionProvider)
        .patentBrandProduct(productId: productId);
    if (!mounted) return;
    final success = result['success'] == true;
    final message = (result['message'] ?? 'Patent işlemi tamamlanamadı.')
        .toString();

    AppSnackbar.show(
      context,
      title: success ? 'Başarılı' : 'Hata',
      message: message,
      type: success ? SnackbarType.success : SnackbarType.error,
    );
  }

  Future<void> _startCampaign(String campaignType) async {
    setState(() => _isSubmitting = true);
    final result = await ref
        .read(companyActionProvider)
        .startMarketingCampaign(campaignType: campaignType);
    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: result['success'] == true ? 'Başarılı' : 'Hata',
      message: (result['message'] ?? 'İşlem tamamlanamadı.').toString(),
      type: result['success'] == true
          ? SnackbarType.success
          : SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final productsAsync = ref.watch(playerBrandCompanyProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Marka'),
            Expanded(
              child: companyAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, _) => _buildError(error.toString()),
                data: (company) {
                  if (company == null) {
                    return _buildSetupState();
                  }

                  return productsAsync.when(
                    loading: () => Center(
                      child: AppLoadingIndicator(color: AppColors.gold),
                    ),
                    error: (error, _) => _buildError(error.toString()),
                    data: (products) =>
                        _buildManagementState(company, products),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Text(
          message,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.bodyLarge,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSetupState() {
    final themeColor = _parseHexColor(_selectedColor);

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: AppDecorations.panelGlass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marka Şirketi Kur',
                style: AppTextStyles.h1.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.displaySmall,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Kendi markanı oluşturarak ürettiğin Kalite 2 ürünleri patentleyebilir, markalı mağaza satışlarında fiyat ve hız bonusları kazanabilirsin.',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.body,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),

              // Brand Name Input
              TextField(
                controller: _brandNameController,
                style: AppTextStyles.input,
                decoration: InputDecoration(
                  labelText: 'Marka Adı',
                  labelStyle: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: themeColor),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Logo Selector
              Text(
                'Marka Logosu',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                height: 64.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: brandLogoOptions.length,
                  itemBuilder: (context, index) {
                    final logo = brandLogoOptions[index];
                    final isSelected = _selectedLogo == logo;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedLogo = logo),
                      child: Container(
                        margin: EdgeInsets.only(right: 12.w),
                        width: 54.w,
                        height: 54.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppFx.panelWash(0.26),
                          border: Border.all(
                            color: isSelected
                                ? themeColor
                                : AppColors.border.withValues(alpha: 0.5),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        padding: EdgeInsets.all(6.w),
                        child: ClipOval(
                          child: CachedAssetImage(
                            fileName: logo,
                            fit: BoxFit.contain,
                            placeholder: const SizedBox.shrink(),
                            errorWidget: Icon(
                              AppIcons.star,
                              color: AppColors.gold,
                              size: AppIconSizes.medium,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20.h),

              // Color Selector
              Text(
                'Marka Rengi',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:
                    [
                      {'name': 'Altın', 'hex': '#E5C05C'},
                      {'name': 'Mavi', 'hex': '#4A90E2'},
                      {'name': 'Yeşil', 'hex': '#50E3C2'},
                      {'name': 'Kırmızı', 'hex': '#E25050'},
                      {'name': 'Mor', 'hex': '#BD10E0'},
                    ].map((colorMap) {
                      final hex = colorMap['hex']!;
                      final color = _parseHexColor(hex);
                      final isSelected = _selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 28.h),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: AppColors.textOnAccent,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 5,
                    shadowColor: themeColor.withValues(alpha: 0.3),
                  ),
                  child: Text(
                    _isSubmitting ? 'Kuruluyor...' : 'Marka Şirketini Kur',
                    style: AppTextStyles.button.standardCopyWith(
                      fontSize: AppTypography.title,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandHeaderCard(
    BrandCompanyModel company,
    List<BrandCompanyProductModel> brandedProducts,
  ) {
    final brandColor = _parseHexColor(company.themeColor);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo Circle
              Container(
                width: 52.w,
                height: 52.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.38),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: brandColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedAssetImage(
                    fileName: company.logoId,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox.shrink(),
                    errorWidget: Icon(AppIcons.star, color: AppColors.gold),
                  ),
                ),
              ),
              SizedBox(width: 14.w),

              // Identity Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          company.brandName,
                          style: AppTextStyles.h1.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.headline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'LVL ${company.brandLevel}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textOnAccent,
                              fontSize: AppTypography.caption,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Aktif Markalı Ürün: ${brandedProducts.length}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // XP Progress Bar Layout
          Builder(
            builder: (context) {
              final currentLvl = company.brandLevel;
              final currentXp = company.brandXp;
              final baseLvlXp = getXpBaseForLevel(currentLvl);
              final nextLvlXp = getXpRequiredForNextLevel(currentLvl);

              final lvlProgress = nextLvlXp == baseLvlXp
                  ? 1.0
                  : ((currentXp - baseLvlXp) / (nextLvlXp - baseLvlXp)).clamp(
                      0.0,
                      1.0,
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Marka Tecrübesi (XP)',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        currentLvl >= 5
                            ? 'MAX LEVEL ($currentXp XP)'
                            : '$currentXp / $nextLvlXp XP',
                        style: AppTextStyles.body.standardCopyWith(
                          color: brandColor,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  AppProgressBar(value: lvlProgress, color: brandColor),
                  SizedBox(height: 6.h),
                  Text(
                    currentLvl >= 5
                        ? 'En yüksek marka prestijine ulaştın! Mağaza satış hızı (+%35) ve taban fiyat toleransı bonusu maksimumda.'
                        : 'Bir sonraki seviye için ${(nextLvlXp - currentXp).clamp(0, nextLvlXp)} XP gerekiyor. Mağazalarında markalı ürün sattıkça yada başkası sizin ürününüzü sattıkça tecrübe kazanırsın.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.label,
                      height: 1.3,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(Color brandColor) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.38),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? brandColor.withValues(alpha: 0.18)
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  border: _selectedTab == 0
                      ? Border.all(color: brandColor.withValues(alpha: 0.35))
                      : null,
                ),
                child: Text(
                  'Patentler & Ürünler',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.standardCopyWith(
                    color: _selectedTab == 0
                        ? brandColor
                        : AppColors.textSecondary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? brandColor.withValues(alpha: 0.18)
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                  border: _selectedTab == 1
                      ? Border.all(color: brandColor.withValues(alpha: 0.35))
                      : null,
                ),
                child: Text(
                  'Pazarlama',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.standardCopyWith(
                    color: _selectedTab == 1
                        ? brandColor
                        : AppColors.textSecondary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketingTab(Color brandColor, BrandCompanyModel company) {
    final activeCampaignsAsync = ref.watch(activeMarketingCampaignsProvider);

    return activeCampaignsAsync.when(
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: AppLoadingIndicator(color: AppColors.gold),
        ),
      ),
      error: (err, _) => _buildError(err.toString()),
      data: (activeCampaigns) {
        final isLocalActive = activeCampaigns.any(
          (c) => c['campaign_type'] == 'local',
        );
        final isRegionalActive = activeCampaigns.any(
          (c) => c['campaign_type'] == 'regional',
        );
        final isGlobalActive = activeCampaigns.any(
          (c) => c['campaign_type'] == 'global',
        );

        final localCampaign = activeCampaigns.firstWhere(
          (c) => c['campaign_type'] == 'local',
          orElse: () => <String, dynamic>{},
        );
        final regionalCampaign = activeCampaigns.firstWhere(
          (c) => c['campaign_type'] == 'regional',
          orElse: () => <String, dynamic>{},
        );
        final globalCampaign = activeCampaigns.firstWhere(
          (c) => c['campaign_type'] == 'global',
          orElse: () => <String, dynamic>{},
        );

        return Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(14.w),
              decoration: AppDecorations.panelGlass(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pazarlama Stratejisi',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Nakit harcayarak mağazalarındaki satış hızını ve fiyat toleransını geçici olarak artırabilirsin. Her reklam türünden aynı anda en fazla bir adet aktif olabilir.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.bodySmall,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            _buildCampaignCard(
              title: 'Yerel Reklam Panoları',
              type: 'local',
              cost: '25.000',
              duration: '24 Saat',
              effects: '+%15 Satış Hızı, +%5 Fiyat Primi Toleransı',
              isActive: isLocalActive,
              activeCampaign: localCampaign,
              brandColor: brandColor,
            ),
            _buildCampaignCard(
              title: 'Bölgesel TV & Radyo',
              type: 'regional',
              cost: '75.000',
              duration: '24 Saat',
              effects: '+%30 Satış Hızı, +%10 Fiyat Primi Toleransı',
              isActive: isRegionalActive,
              activeCampaign: regionalCampaign,
              brandColor: brandColor,
            ),
            _buildCampaignCard(
              title: 'Küresel Dijital Reklamlar',
              type: 'global',
              cost: '200.000',
              duration: '48 Saat',
              effects: '+%50 Satış Hızı, +%20 Fiyat Primi Toleransı',
              isActive: isGlobalActive,
              activeCampaign: globalCampaign,
              brandColor: brandColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCampaignCard({
    required String title,
    required String type,
    required String cost,
    required String duration,
    required String effects,
    required bool isActive,
    required Map<String, dynamic> activeCampaign,
    required Color brandColor,
  }) {
    String remainingText = '';
    if (isActive) {
      final activeUntilStr = activeCampaign['active_until'] as String?;
      if (activeUntilStr != null) {
        final activeUntil = DateTime.tryParse(activeUntilStr)?.toLocal();
        if (activeUntil != null) {
          final diff = activeUntil.difference(DateTime.now());
          if (!diff.isNegative) {
            final hours = diff.inHours;
            final minutes = diff.inMinutes % 60;
            remainingText = '$hours sa $minutes dk kaldı';
          }
        }
      }
    }

    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(isActive ? brandColor : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isActive) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'AKTİF',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: brandColor,
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'Maliyet: $cost₺  •  Süre: $duration',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  effects,
                  style: AppTextStyles.body.standardCopyWith(
                    color: brandColor.withValues(alpha: 0.85),
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isActive && remainingText.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        AppIcons.timerOutlined,
                        color: brandColor,
                        size: 12.w,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        remainingText,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: isActive || _isSubmitting
                ? null
                : () => _startCampaign(type),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.textMuted : brandColor,
              foregroundColor: AppColors.textOnAccent,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Başlat',
              style: AppTextStyles.button.standardCopyWith(
                fontSize: AppTypography.body,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementState(
    BrandCompanyModel company,
    List<BrandCompanyProductModel> products,
  ) {
    final brandedProducts = products.where((item) => item.isBranded).toList();
    final availableProducts = products
        .where((item) => !item.isBranded)
        .toList();

    final brandColor = _parseHexColor(company.themeColor);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(playerBrandCompanyProvider);
        ref.invalidate(playerBrandCompanyProductsProvider);
        ref.invalidate(activeMarketingCampaignsProvider);
      },
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        children: [
          // XP progress card and Brand identity
          _buildBrandHeaderCard(company, brandedProducts),

          // Tab switcher
          _buildTabSwitcher(brandColor),

          SizedBox(height: 8.h),

          if (_selectedTab == 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildSectionTitle('Markalanabilir Ürünler'),
            ),
            SizedBox(height: 8.h),
            if (availableProducts.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: _buildEmptyCard(
                  'Kalite 2 seviyesinde patentlenebilir yeni ürün yok.',
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: availableProducts
                      .map(
                        (item) =>
                            _buildPatentCard(item, brandColor: brandColor),
                      )
                      .toList(),
                ),
              ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildSectionTitle('Markalı Ürünler'),
            ),
            SizedBox(height: 8.h),
            if (brandedProducts.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: _buildEmptyCard(
                  'Bu marka altında henüz aktif ürün yok.',
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: brandedProducts
                      .map(
                        (item) => _buildPatentCard(
                          item,
                          readOnly: true,
                          brandId: company.id,
                          brandName: company.brandName,
                          brandColor: brandColor,
                        ),
                      )
                      .toList(),
                ),
              ),
          ] else ...[
            _buildMarketingTab(brandColor, company),
          ],
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/company/design'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: BorderSide(color: brandColor.withValues(alpha: 0.35)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: const Icon(AppIcons.paletteOutlined),
                label: const Text('Marka Tasarımını Düzenle'),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.title.standardCopyWith(
        color: AppColors.textPrimary,
        fontSize: AppTypography.titleLarge,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.panelGlass(),
      child: Text(
        message,
        style: AppTextStyles.body.standardCopyWith(
          color: AppColors.textSecondary,
          fontSize: AppTypography.body,
        ),
      ),
    );
  }

  Widget _buildPatentCard(
    BrandCompanyProductModel item, {
    bool readOnly = false,
    String? brandId,
    String? brandName,
    required Color brandColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(readOnly ? brandColor : null),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.16),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: BrandedProductImage(
              fileName: item.productIcon,
              fit: BoxFit.contain,
              brandId: readOnly ? brandId : null,
              brandName: readOnly ? brandName : null,
              productId: item.productId,
              watermarkAssetId: item.watermarkAssetId,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Maks kalite: ${item.maxQualityLevel}',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (readOnly) ...[
            OutlinedButton(
              onPressed: () =>
                  context.push('/company/products/${item.productId}/design'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandColor,
                side: BorderSide(color: brandColor.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: const Text('Tasarim'),
            ),
            SizedBox(width: 8.w),
          ],
          ElevatedButton(
            onPressed: readOnly ? null : () => _patentProduct(item.productId),
            style: ElevatedButton.styleFrom(
              backgroundColor: readOnly
                  ? brandColor.withValues(alpha: 0.16)
                  : brandColor,
              foregroundColor: readOnly ? brandColor : AppColors.textOnAccent,
              side: readOnly
                  ? BorderSide(color: brandColor.withValues(alpha: 0.35))
                  : null,
            ),
            child: Text(readOnly ? 'Markalı' : 'Patent Al (50.000 ₺)'),
          ),
        ],
      ),
    );
  }
}
