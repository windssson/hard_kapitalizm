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
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  // Custom brand selections for setup state
  String _selectedLogo = defaultBrandLogoId;
  String _selectedColor = '#E5C05C';

  // Sub-tab inside brand management state
  // 0: Patentler & Ürünler, 1: Pazarlama
  int _selectedTab = 0;

  // Product sub-filter: 0: Tümü, 1: Tescilli, 2: Patentlenebilir
  int _productFilter = 0;

  @override
  void dispose() {
    _brandNameController.dispose();
    _searchController.dispose();
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

  String _getLevelTitle(int currentLevel) {
    switch (currentLevel) {
      case 1:
        return 'Yerel Girişim';
      case 2:
        return 'Bölgesel Güç';
      case 3:
        return 'Ulusal Holding';
      case 4:
        return 'Kıtasal Lider';
      case 5:
        return 'Global Dev';
      default:
        return 'Yerel Girişim';
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
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.gold, size: 22.w),
            SizedBox(width: 8.w),
            Text(
              'Ürün Patentleme',
              style: AppTextStyles.h2.standardCopyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Bu ürünü markanız altına tescil etmek istiyor musunuz?\n\n'
          'Maliyet: 50.000 ₺\n'
          'Tescillenen ürünler bundan sonra fabrikanızda ve tarlalarınızda logonuzla üretilecek, mağazalarda marka prestijinden faydalanacaktır.',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Patent Al (50.000 ₺)',
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

  Future<void> _showRenameDialog(BrandCompanyModel company) async {
    final controller = TextEditingController(text: company.brandName);
    final formKey = GlobalKey<FormState>();
    final brandColor = _parseHexColor(company.themeColor);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: brandColor, size: 24.w),
            SizedBox(width: 8.w),
            Text(
              'Marka Adını Değiştir',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni marka adınızı belirleyin (3-24 karakter, Türkçe/Latin harf ve rakamlar):',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.input,
                decoration: InputDecoration(
                  hintText: 'Yeni Marka Adı',
                  hintStyle: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: brandColor),
                  ),
                ),
                validator: (val) {
                  final trimmed = (val ?? '').trim();
                  if (trimmed.length < 3) return 'En az 3 karakter olmalıdır.';
                  if (trimmed.length > 24) return 'En fazla 24 karakter olabilir.';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: AppTextStyles.button.standardCopyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != company.brandName) {
      setState(() => _isSubmitting = true);
      final result = await ref.read(companyActionProvider).updateBrandCompany(
            logoId: company.logoId,
            themeColor: company.themeColor,
            brandName: newName,
          );
      if (mounted) setState(() => _isSubmitting = false);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: result['success'] == true ? 'Başarılı' : 'Hata',
        message: (result['message'] ?? '').toString(),
        type: result['success'] == true ? SnackbarType.success : SnackbarType.error,
      );
    }
  }

  void _showLevelBonusesDialog(BrandCompanyModel company) {
    final brandColor = _parseHexColor(company.themeColor);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: brandColor, size: 24.w),
            SizedBox(width: 8.w),
            Text(
              'Marka Seviye Avantajları',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Marka seviyeniz arttıkça mağazalarınızda markalı ürünlerin satış hızı katlanır ve fiyat toleransı kazanırsınız.',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                ),
              ),
              SizedBox(height: 14.h),
              _buildLevelRow(1, 'Yerel Girişim', '+%5 Hız, %25 Fiyat Toleransı', '0 XP', company.brandLevel == 1, brandColor),
              _buildLevelRow(2, 'Bölgesel Güç', '+%10 Hız, %25 Fiyat Toleransı', '1.000 XP', company.brandLevel == 2, brandColor),
              _buildLevelRow(3, 'Ulusal Holding', '+%15 Hız, %25 Fiyat Toleransı', '5.000 XP', company.brandLevel == 3, brandColor),
              _buildLevelRow(4, 'Kıtasal Lider', '+%20 Hız, %25 Fiyat Toleransı', '15.000 XP', company.brandLevel == 4, brandColor),
              _buildLevelRow(5, 'Global Dev', '+%25 Hız, %25 Fiyat Toleransı', '40.000 XP', company.brandLevel == 5, brandColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Anladım', style: AppTextStyles.button.standardCopyWith(color: brandColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(
    int level,
    String title,
    String bonus,
    String xpRequired,
    bool isCurrent,
    Color brandColor,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isCurrent ? brandColor.withValues(alpha: 0.15) : AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isCurrent ? brandColor : AppColors.border.withValues(alpha: 0.4),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isCurrent ? brandColor : AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              'LVL $level',
              style: AppTextStyles.caption.standardCopyWith(
                color: isCurrent ? AppColors.textOnAccent : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title.standardCopyWith(
                        color: isCurrent ? brandColor : AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      xpRequired,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  bonus,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent) ...[
            SizedBox(width: 6.w),
            Icon(Icons.check_circle_rounded, color: brandColor, size: 18.w),
          ],
        ],
      ),
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
            const SecondaryTopBar(title: 'Marka & Holding'),
            Expanded(
              child: companyAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
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

  // ===========================================================================
  // BRAND SETUP (CREATION) STATE WITH LIVE PREVIEW
  // ===========================================================================
  Widget _buildSetupState() {
    final themeColor = _parseHexColor(_selectedColor);
    final brandNameInput = _brandNameController.text.trim();
    final previewName = brandNameInput.isEmpty ? 'Holdinginizin Adı' : brandNameInput;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        // Live Preview Emblem Card
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withValues(alpha: 0.16),
                AppColors.cardBg.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'CANLI ÖNİZLEME',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: themeColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'LVL 1 • Yerel Girişim',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppFx.panelWash(0.4),
                      border: Border.all(color: themeColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedAssetImage(
                        fileName: _selectedLogo,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: Icon(AppIcons.star, color: themeColor),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewName,
                          style: AppTextStyles.h1.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.headline,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14.w, color: themeColor),
                            SizedBox(width: 4.w),
                            Text(
                              '+%5 Satış Hızı, %25 Fiyat Toleransı',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: themeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // Brand Form Container
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: AppDecorations.panelGlass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marka Şirketi Tescili',
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Kendi kurumsal markanızı tescil ederek ürettiğiniz Kalite 2+ ürünleri patentleyebilir, mağazalarınızda piyasa üstü kâr marjlarıyla satış yapabilirsiniz.',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18.h),

              // Brand Name Input
              TextField(
                controller: _brandNameController,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.input,
                decoration: InputDecoration(
                  labelText: 'Marka Adı',
                  labelStyle: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                  ),
                  hintText: 'Örn: Anadolu Holding',
                  hintStyle: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: themeColor, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Logo Selector
              Text(
                'Şirket Logosu',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                height: 62.h,
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
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppFx.panelWash(0.26),
                          border: Border.all(
                            color: isSelected ? themeColor : AppColors.border.withValues(alpha: 0.5),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.35),
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
                            errorWidget: Icon(AppIcons.star, color: AppColors.gold),
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
                'Kurumsal Renk',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 12.w,
                runSpacing: 10.h,
                children: brandColorOptions.map((colorMap) {
                  final hex = colorMap['hex']!;
                  final color = _parseHexColor(hex);
                  final isSelected = _selectedColor == hex;
                  final name = colorMap['name'] ?? '';

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Column(
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? AppColors.textPrimary : AppColors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: AppColors.textPrimary, size: 20.w)
                              : null,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          name,
                          style: AppTextStyles.caption.standardCopyWith(
                            color: isSelected ? themeColor : AppColors.textSecondary,
                            fontSize: AppTypography.label,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 26.h),

              // Submit Button
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
                    shadowColor: themeColor.withValues(alpha: 0.35),
                  ),
                  child: Text(
                    _isSubmitting ? 'Tescilleniyor...' : 'Markayı Tescille ve Kur',
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

  // ===========================================================================
  // LUXURY HOLDING HERO HEADER
  // ===========================================================================
  Widget _buildBrandHeaderCard(
    BrandCompanyModel company,
    List<BrandCompanyProductModel> brandedProducts,
  ) {
    final brandColor = _parseHexColor(company.themeColor);
    final title = _getLevelTitle(company.brandLevel);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandColor.withValues(alpha: 0.14),
            AppColors.cardBg.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Emblem + Brand Info + Quick Action Buttons
          Row(
            children: [
              // Logo Emblem Circle
              Container(
                width: 58.w,
                height: 58.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: brandColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedAssetImage(
                    fileName: company.logoId,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox.shrink(),
                    errorWidget: Icon(AppIcons.star, color: brandColor),
                  ),
                ),
              ),
              SizedBox(width: 14.w),

              // Title, Level & Prestige
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            company.brandName,
                            style: AppTextStyles.h1.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.headline,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16.w,
                            color: AppColors.textMuted,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Marka Adını Değiştir',
                          onPressed: () => _showRenameDialog(company),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showLevelBonusesDialog(company),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LVL ${company.brandLevel}',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textOnAccent,
                                    fontSize: AppTypography.label,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Icon(
                                  Icons.info_outline,
                                  size: 11.w,
                                  color: AppColors.textOnAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          title,
                          style: AppTextStyles.body.standardCopyWith(
                            color: brandColor,
                            fontSize: AppTypography.bodySmall,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Design Edit Button
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: brandColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    size: 18.w,
                    color: brandColor,
                  ),
                ),
                tooltip: 'Marka Tasarımını Düzenle',
                onPressed: () => context.push('/company/design'),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Micro Stats Ribbon
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _buildMicroStatPill(
                icon: Icons.inventory_2_outlined,
                label: '${brandedProducts.length} Patentli Ürün',
                color: AppColors.textSecondary,
              ),
              _buildMicroStatPill(
                icon: Icons.speed_rounded,
                label: company.brandLevel >= 5 ? '+%25 Satış Hızı' : '+${company.brandLevel * 5}% Satış Hızı',
                color: brandColor,
              ),
              _buildMicroStatPill(
                icon: Icons.trending_up_rounded,
                label: '+%25 Fiyat Toleransı',
                color: AppColors.green,
              ),
            ],
          ),

          SizedBox(height: 14.h),

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
                            ? 'MAX SEVİYE ($currentXp XP)'
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
                        ? 'En yüksek marka prestijine ulaştınız! Mağaza satış hızı ve taban fiyat toleransı bonusu zirvede.'
                        : 'Bir sonraki seviye için ${(nextLvlXp - currentXp).clamp(0, nextLvlXp)} XP gerekiyor. Mağazalarda markalı ürün satıldıkça markanız XP kazanır.',
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

  Widget _buildMicroStatPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.22),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.w, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXECUTIVE FINANCIAL PERFORMANCE PANEL
  // ===========================================================================
  Widget _buildBrandPerformanceCard(Color brandColor) {
    final performanceAsync = ref.watch(playerBrandPerformanceProvider);

    return performanceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (perf) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          padding: EdgeInsets.all(16.w),
          decoration: AppDecorations.panelGlass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.query_stats_rounded, color: brandColor, size: 20.w),
                      SizedBox(width: 6.w),
                      Text(
                        'Marka Satış Performansı',
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 18.w),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Yenile',
                    onPressed: () => ref.read(playerBrandPerformanceProvider.notifier).refresh(),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Satılan Adet',
                      value: '${perf.totalSold} ad.',
                      color: AppColors.textPrimary,
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Marka Cirosu',
                      value: AppMoney.compact(perf.totalRevenue),
                      color: brandColor,
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Marka Kârı',
                      value: AppMoney.compact(perf.totalProfit),
                      color: AppColors.green,
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),
              if (perf.topProducts.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  'En Çok Satan Markalı Ürünler',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: perf.topProducts.take(3).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final top = entry.value;
                    final medalColor = index == 0
                        ? AppColors.gold
                        : index == 1
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFCD7F32);

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: AppFx.panelWash(0.2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16.w,
                            height: 16.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: medalColor.withValues(alpha: 0.2),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: medalColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '${top.productName} • ${top.soldQuantity} ad (${AppMoney.compact(top.revenue)})',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textSecondary,
                              fontSize: AppTypography.label,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.18),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.w, color: AppColors.textMuted),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.title.standardCopyWith(
              color: color,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEGMENTED TAB SWITCHER
  // ===========================================================================
  Widget _buildTabSwitcher(
    Color brandColor,
    int productCount,
    int activeCampaignCount,
  ) {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16.w,
                      color: _selectedTab == 0 ? brandColor : AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Patentler ($productCount)',
                      style: AppTextStyles.body.standardCopyWith(
                        color: _selectedTab == 0 ? brandColor : AppColors.textSecondary,
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 18.w,
                      color: _selectedTab == 1 ? brandColor : AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      activeCampaignCount > 0
                          ? 'Pazarlama ($activeCampaignCount Aktif)'
                          : 'Pazarlama',
                      style: AppTextStyles.body.standardCopyWith(
                        color: _selectedTab == 1 ? brandColor : AppColors.textSecondary,
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (activeCampaignCount > 0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MARKETING TAB WITH TIER VISUAL IDENTITY & LIVE COUNTDOWN
  // ===========================================================================
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
              padding: EdgeInsets.all(16.w),
              decoration: AppDecorations.panelGlass(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.ads_click_rounded, color: brandColor, size: 20.w),
                      SizedBox(width: 8.w),
                      Text(
                        'Pazarlama & Reklam Stratejisi',
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Reklam bütçesi ayırarak mağazalarınızdaki satış hızını ve müşterilerin fiyat toleransını artırabilirsiniz. Her reklam türünden aynı anda en fazla 1 adet aktif olabilir.',
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
              speedBonus: '+%15 Satış Hızı',
              priceBonus: '+%5 Fiyat Toleransı',
              tierIcon: Icons.campaign_outlined,
              tierColor: const Color(0xFFF59E0B),
              isActive: isLocalActive,
              activeCampaign: localCampaign,
              brandColor: brandColor,
            ),
            _buildCampaignCard(
              title: 'Bölgesel TV & Radyo',
              type: 'regional',
              cost: '75.000',
              duration: '24 Saat',
              speedBonus: '+%30 Satış Hızı',
              priceBonus: '+%10 Fiyat Toleransı',
              tierIcon: Icons.cell_tower_outlined,
              tierColor: const Color(0xFF3B82F6),
              isActive: isRegionalActive,
              activeCampaign: regionalCampaign,
              brandColor: brandColor,
            ),
            _buildCampaignCard(
              title: 'Küresel Dijital Kampanya',
              type: 'global',
              cost: '200.000',
              duration: '48 Saat',
              speedBonus: '+%50 Satış Hızı',
              priceBonus: '+%20 Fiyat Toleransı',
              tierIcon: Icons.public_rounded,
              tierColor: const Color(0xFFA855F7),
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
    required String speedBonus,
    required String priceBonus,
    required IconData tierIcon,
    required Color tierColor,
    required bool isActive,
    required Map<String, dynamic> activeCampaign,
    required Color brandColor,
  }) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    String remainingText = '';
    if (isActive) {
      final activeUntilStr = activeCampaign['active_until'] as String?;
      if (activeUntilStr != null) {
        final activeUntil = DateTime.tryParse(activeUntilStr)?.toLocal();
        if (activeUntil != null) {
          final diff = activeUntil.difference(now);
          if (!diff.isNegative) {
            final hours = diff.inHours;
            final minutes = diff.inMinutes % 60;
            final seconds = diff.inSeconds % 60;
            remainingText = '${hours}s ${minutes}d ${seconds}sn kaldı';
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(activeMarketingCampaignsProvider.notifier).refresh();
              }
            });
          }
        }
      }
    }

    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isActive ? tierColor.withValues(alpha: 0.15) : AppFx.panelWash(0.2),
            AppColors.cardBg.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isActive ? tierColor : AppColors.border.withValues(alpha: 0.4),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: tierColor.withValues(alpha: 0.35)),
                ),
                child: Icon(tierIcon, color: tierColor, size: 18.w),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isActive) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.green,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'CANLI',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _buildMicroStatPill(
                icon: Icons.bolt_rounded,
                label: speedBonus,
                color: tierColor,
              ),
              SizedBox(width: 6.w),
              _buildMicroStatPill(
                icon: Icons.trending_up_rounded,
                label: priceBonus,
                color: AppColors.green,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maliyet: $cost ₺  •  Süre: $duration',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                  if (isActive && remainingText.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(AppIcons.timerOutlined, color: tierColor, size: 12.w),
                        SizedBox(width: 4.w),
                        Text(
                          remainingText,
                          style: AppTextStyles.caption.standardCopyWith(
                            color: tierColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              ElevatedButton(
                onPressed: isActive || _isSubmitting ? null : () => _startCampaign(type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? AppColors.textMuted : tierColor,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
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
        ],
      ),
    );
  }

  // ===========================================================================
  // MANAGEMENT STATE (HOLDING HUB)
  // ===========================================================================
  Widget _buildManagementState(
    BrandCompanyModel company,
    List<BrandCompanyProductModel> products,
  ) {
    final activeCampaignsAsync = ref.watch(activeMarketingCampaignsProvider);
    final activeCount = activeCampaignsAsync.value?.length ?? 0;

    final brandedProducts = products.where((item) => item.isBranded).toList();
    final availableProducts = products.where((item) => !item.isBranded).toList();

    // Filter by search query
    List<BrandCompanyProductModel> displayList;
    if (_productFilter == 1) {
      displayList = brandedProducts;
    } else if (_productFilter == 2) {
      displayList = availableProducts;
    } else {
      displayList = products;
    }

    if (_searchQuery.isNotEmpty) {
      displayList = displayList
          .where((item) => item.productName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    final brandColor = _parseHexColor(company.themeColor);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(playerBrandCompanyProvider.notifier).refresh();
        await ref.read(playerBrandCompanyProductsProvider.notifier).refresh();
        await ref.read(activeMarketingCampaignsProvider.notifier).refresh();
        await ref.read(playerBrandPerformanceProvider.notifier).refresh();
      },
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        children: [
          // Luxury Hero Header
          _buildBrandHeaderCard(company, brandedProducts),

          // Executive Financial Performance Panel
          _buildBrandPerformanceCard(brandColor),

          // Tab Switcher (Patentler vs Pazarlama)
          _buildTabSwitcher(brandColor, products.length, activeCount),

          SizedBox(height: 6.h),

          if (_selectedTab == 0) ...[
            // Search Bar & Filter Chips
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  // Search Box
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: AppFx.panelWash(0.25),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20.w),
                        hintText: 'Ürünlerde ara...',
                        hintStyle: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18.w),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Sub-filter chips (Tümü, Tescilli, Patent Alınabilir)
                  Row(
                    children: [
                      _buildFilterChip('Tümü (${products.length})', 0, brandColor),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Tescilli (${brandedProducts.length})', 1, brandColor),
                      SizedBox(width: 8.w),
                      _buildFilterChip('Patentlenebilir (${availableProducts.length})', 2, brandColor),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Products List
            if (displayList.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: _buildEmptyCard(
                  _searchQuery.isNotEmpty
                      ? 'Aramanıza uygun ürün bulunamadı.'
                      : _productFilter == 1
                          ? 'Henüz markanız altında tescilli ürün bulunmuyor.'
                          : 'Kalite 2 seviyesinde patentlenebilir yeni ürün yok.',
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: displayList.map((item) {
                    return _buildPatentCard(
                      item,
                      readOnly: item.isBranded,
                      brandId: company.id,
                      brandName: company.brandName,
                      brandColor: brandColor,
                    );
                  }).toList(),
                ),
              ),
          ] else ...[
            _buildMarketingTab(brandColor, company),
          ],
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int filterIndex, Color brandColor) {
    final isSelected = _productFilter == filterIndex;
    return GestureDetector(
      onTap: () => setState(() => _productFilter = filterIndex),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withValues(alpha: 0.18) : AppFx.panelWash(0.2),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? brandColor : AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: isSelected ? brandColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: AppTypography.label,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 36.w, color: AppColors.textMuted),
          SizedBox(height: 8.h),
          Text(
            message,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.body,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT PATENT CARD WITH WATERMARK & QUALITY BADGES
  // ===========================================================================
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
      decoration: BoxDecoration(
        color: readOnly ? brandColor.withValues(alpha: 0.07) : AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: readOnly ? brandColor.withValues(alpha: 0.35) : AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Product Icon with Watermark
          Container(
            width: 52.w,
            height: 52.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.25),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: readOnly ? brandColor.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.3),
              ),
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

          // Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.productName,
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.title,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.watermarkAssetId != null && item.watermarkAssetId!.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.verified_rounded, size: 14.w, color: brandColor),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'Q${item.maxQualityLevel}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      readOnly ? 'Tescilli Ürün' : 'Patent Alınabilir',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: readOnly ? brandColor : AppColors.textSecondary,
                        fontSize: AppTypography.label,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),

          // Action Buttons
          if (readOnly) ...[
            OutlinedButton.icon(
              onPressed: () => context.push('/company/products/${item.productId}/design'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandColor,
                side: BorderSide(color: brandColor.withValues(alpha: 0.35)),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              icon: Icon(Icons.style_outlined, size: 14.w),
              label: Text(
                'Filigran',
                style: AppTextStyles.button.standardCopyWith(fontSize: AppTypography.bodySmall),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => _patentProduct(item.productId),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: AppColors.textOnAccent,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Patent Al\n50.000 ₺',
                textAlign: TextAlign.center,
                style: AppTextStyles.button.standardCopyWith(
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
