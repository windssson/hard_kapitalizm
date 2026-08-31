import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_design_options.dart';

class BrandDesignScreen extends ConsumerStatefulWidget {
  const BrandDesignScreen({super.key});

  @override
  ConsumerState<BrandDesignScreen> createState() => _BrandDesignScreenState();
}

class _BrandDesignScreenState extends ConsumerState<BrandDesignScreen> {
  String? _selectedLogo;
  String? _selectedColor;
  bool _didInitialize = false;
  bool _isSaving = false;

  Future<void> _saveBrandDesign(String logoId, String themeColor) async {
    setState(() => _isSaving = true);
    final result = await ref.read(companyActionProvider).updateBrandCompany(
          logoId: logoId,
          themeColor: themeColor,
        );
    if (mounted) {
      setState(() => _isSaving = false);
    }

    if (!mounted) return;
    final success = result['success'] == true;
    AppSnackbar.show(
      context,
      title: success ? 'Başarılı' : 'Hata',
      message: (result['message'] ?? 'İşlem tamamlanamadı.').toString(),
      type: success ? SnackbarType.success : SnackbarType.error,
    );
    if (success) {
      Navigator.pop(context);
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

  void _syncSelections({
    required String logoId,
    required String themeColor,
  }) {
    if (_didInitialize) return;
    _selectedLogo = logoId;
    _selectedColor = themeColor;
    _didInitialize = true;
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerBrandCompanyProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Marka Tasarımı'),
            Expanded(
              child: companyAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(error.toString()),
                data: (company) {
                  if (company == null) {
                    return _buildErrorState(
                      'Düzenlenecek aktif marka bulunamadı.',
                    );
                  }

                  _syncSelections(
                    logoId: brandLogoOptions.contains(company.logoId)
                        ? company.logoId
                        : defaultBrandLogoId,
                    themeColor: company.themeColor,
                  );

                  final selectedLogo = _selectedLogo ?? defaultBrandLogoId;
                  final selectedColor = _selectedColor ?? company.themeColor;
                  final brandColor = _parseHexColor(selectedColor);

                  return ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                    children: [
                      _buildPreviewCard(
                        brandName: company.brandName,
                        selectedLogo: selectedLogo,
                        brandColor: brandColor,
                      ),
                      SizedBox(height: 16.h),
                      _buildInfoCard(
                        'Bu sayfada marka logonu ve ana rengini yeniden kurgulayabilirsin.',
                      ),
                      SizedBox(height: 16.h),
                      _buildSectionTitle('Logo Seçimi'),
                      SizedBox(height: 10.h),
                      SizedBox(
                        height: 72.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: brandLogoOptions.length,
                          itemBuilder: (context, index) {
                            final logo = brandLogoOptions[index];
                            final isSelected = selectedLogo == logo;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedLogo = logo),
                              child: Container(
                                margin: EdgeInsets.only(right: 12.w),
                                width: 62.w,
                                height: 62.w,
                                padding: EdgeInsets.all(7.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppFx.panelWash(0.26),
                                  border: Border.all(
                                    color: isSelected
                                        ? brandColor
                                        : AppColors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: brandColor.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipOval(
                                  child: CachedAssetImage(
                                    fileName: logo,
                                    fit: BoxFit.contain,
                                    placeholder: const SizedBox.shrink(),
                                    errorWidget: Icon(
                                      AppIcons.star,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20.h),
                      _buildSectionTitle('Renk Seçimi'),
                      SizedBox(height: 10.h),
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 12.h,
                        children: _brandColorOptions.map((colorMap) {
                          final hex = colorMap['hex']!;
                          final color = _parseHexColor(hex);
                          final isSelected = selectedColor == hex;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = hex),
                            child: Container(
                              width: 48.w,
                              height: 48.w,
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
                      SizedBox(height: 20.h),
                      _buildInfoCard(
                        'Logonu ve rengini dilediğin gibi değiştirebilirsin. Kaydettiğinde tüm markalı ürünlerinde ve arayüzde yeni tasarımın geçerli olacaktır.',
                      ),
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _saveBrandDesign(selectedLogo, selectedColor),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            foregroundColor: AppColors.textOnAccent,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 5,
                            shadowColor: brandColor.withValues(alpha: 0.3),
                          ),
                          child: Text(
                            _isSaving ? 'Kaydediliyor...' : 'Tasarimi Kaydet',
                            style: AppTextStyles.button.standardCopyWith(
                              fontSize: AppTypography.title,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard({
    required String brandName,
    required String selectedLogo,
    required Color brandColor,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canli Onizleme',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.titleLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Container(
                width: 66.w,
                height: 66.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.38),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: brandColor.withValues(alpha: 0.55),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedAssetImage(
                    fileName: selectedLogo,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox.shrink(),
                    errorWidget: Icon(
                      AppIcons.star,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: AppTextStyles.h1.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: brandColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Tasarim Rengi Aktif',
                        style: AppTextStyles.body.standardCopyWith(
                          color: brandColor,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildInfoCard(String text) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(null, 14.r),
      child: Text(
        text,
        style: AppTextStyles.body.standardCopyWith(
          color: AppColors.textSecondary,
          fontSize: AppTypography.bodySmall,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
      ),
    );
  }
}

const List<Map<String, String>> _brandColorOptions = [
  {'name': 'Altin', 'hex': '#E5C05C'},
  {'name': 'Mavi', 'hex': '#4A90E2'},
  {'name': 'Yesil', 'hex': '#50E3C2'},
  {'name': 'Kirmizi', 'hex': '#E25050'},
  {'name': 'Mor', 'hex': '#BD10E0'},
];
