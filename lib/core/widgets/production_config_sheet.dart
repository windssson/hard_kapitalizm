import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';

class ProductionConfigResult {
  final int qualityLevel;
  final String brandId;

  const ProductionConfigResult({
    required this.qualityLevel,
    required this.brandId,
  });
}

class ProductionConfigSheet extends ConsumerStatefulWidget {
  final ProductModel product;
  final int maxQualityLevel;
  final bool hasPreferredBrand;
  final String preferredBrandId;
  final String? brandName;
  final String facilityType;

  const ProductionConfigSheet({
    super.key,
    required this.product,
    required this.maxQualityLevel,
    required this.hasPreferredBrand,
    required this.preferredBrandId,
    this.brandName,
    this.facilityType = 'Üretim',
  });

  static Future<ProductionConfigResult?> show({
    required BuildContext context,
    required ProductModel product,
    required int maxQualityLevel,
    required bool hasPreferredBrand,
    required String preferredBrandId,
    String? brandName,
    String facilityType = 'Üretim',
  }) {
    return showModalBottomSheet<ProductionConfigResult>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      barrierColor: AppFx.scrim(),
      builder: (sheetContext) => ProductionConfigSheet(
        product: product,
        maxQualityLevel: maxQualityLevel,
        hasPreferredBrand: hasPreferredBrand,
        preferredBrandId: preferredBrandId,
        brandName: brandName,
        facilityType: facilityType,
      ),
    );
  }

  @override
  ConsumerState<ProductionConfigSheet> createState() =>
      _ProductionConfigSheetState();
}

class _ProductionConfigSheetState extends ConsumerState<ProductionConfigSheet> {
  late int _selectedQuality;
  late String _selectedBrandId;

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.maxQualityLevel.clamp(1, 5);
    _selectedBrandId = widget.hasPreferredBrand
        ? widget.preferredBrandId
        : SelectableProductionProductModel.defaultBrandId;
  }

  bool get _hasRawMaterials {
    final p = widget.product;
    return (p.hammadde1Id != null && p.hammadde1Id!.isNotEmpty) ||
        (p.hammadde2Id != null && p.hammadde2Id!.isNotEmpty) ||
        (p.hammadde3Id != null && p.hammadde3Id!.isNotEmpty);
  }

  bool get _isBrandedSelected =>
      _selectedBrandId != SelectableProductionProductModel.defaultBrandId;

  @override
  Widget build(BuildContext context) {
    final brandCompany = ref.watch(playerBrandCompanyProvider).value;
    final resolvedBrandName = widget.brandName ??
        brandCompany?.brandName ??
        'Şirket Markası';

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: AppDecorations.panelGlass(24.r),
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 24.h),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Notch Bar
                  Center(
                    child: Container(
                      width: 38.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 14.h),
                      decoration: BoxDecoration(
                        color: AppFx.softOverlay(0.20),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),

                  // Header Product Info Card
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppFx.softOverlay(0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            width: 50.w,
                            height: 50.h,
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: BrandedProductImage(
                              fileName: widget.product.urunIconu,
                              productId: widget.product.id,
                              brandId: _selectedBrandId,
                              brandName: resolvedBrandName,
                              company: brandCompany,
                              fit: BoxFit.contain,
                              showFrame: false,
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.urunAdi,
                                style: AppTextStyles.h2.standardCopyWith(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      widget.facilityType,
                                      style: AppTextStyles.caption.standardCopyWith(
                                        fontSize: 10.sp,
                                        color: AppColors.goldLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (widget.product.kategori != null) ...[
                                    SizedBox(width: 6.w),
                                    Text(
                                      widget.product.kategori!,
                                      style: AppTextStyles.caption.standardCopyWith(
                                        fontSize: 11.sp,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // --- Section 1: Quality Selection ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Üretim Kalitesi',
                        style: AppTextStyles.body.standardCopyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Maksimum: Q${widget.maxQualityLevel}',
                          style: AppTextStyles.caption.standardCopyWith(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // Quality Level Selector
                  Row(
                    children: List.generate(widget.maxQualityLevel, (index) {
                      final level = index + 1;
                      final isSelected = _selectedQuality == level;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedQuality = level;
                                });
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.gold.withValues(alpha: 0.16)
                                      : AppColors.background.withValues(alpha: 0.40),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.gold
                                        : AppFx.softOverlay(0.12),
                                    width: isSelected ? 1.5.w : 1.w,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.gold
                                                .withValues(alpha: 0.20),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: isSelected
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                      size: 18.sp,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Q$level',
                                      style: AppTextStyles.body.standardCopyWith(
                                        fontSize: 13.sp,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.gold
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Raw Material Warning / Tip
                  if (_hasRawMaterials) ...[
                    SizedBox(height: 10.h),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _selectedQuality > 2
                          ? Container(
                              key: const ValueKey('warning'),
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: const Color(0xFFF59E0B),
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Q$_selectedQuality kalitede üretim için girdi hammaddelerin en az Q${_selectedQuality - 1} olması şarttır. Depoda Q1 hammadde varsa kullanılamaz.',
                                      style: AppTextStyles.caption.standardCopyWith(
                                        color: const Color(0xFFFBBF24),
                                        fontSize: 11.sp,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              key: const ValueKey('info'),
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.success,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Standart (Q1) hammaddeler bu seviyede üretim için uygundur.',
                                      style: AppTextStyles.caption.standardCopyWith(
                                        color: AppColors.green,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],

                  SizedBox(height: 20.h),

                  // --- Section 2: Brand Selection ---
                  Text(
                    'Marka Seçimi',
                    style: AppTextStyles.body.standardCopyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // Option 1: Unbranded / Standart
                  _buildBrandOptionCard(
                    title: 'Standart / Markasız',
                    subtitle: 'Genel pazar satışı ve standart tedarik için uygundur.',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.textSecondary,
                    isSelected: !_isBrandedSelected,
                    onTap: () {
                      setState(() {
                        _selectedBrandId =
                            SelectableProductionProductModel.defaultBrandId;
                      });
                    },
                  ),

                  SizedBox(height: 8.h),

                  // Option 2: Company Brand (if patented)
                  if (widget.hasPreferredBrand)
                    _buildBrandOptionCard(
                      title: resolvedBrandName,
                      subtitle: 'Tescilli marka ile üretim. Primli satış ve prestij sağlar.',
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.gold,
                      badgeText: 'Tescilli Patent',
                      isSelected: _isBrandedSelected,
                      onTap: () {
                        setState(() {
                          _selectedBrandId = widget.preferredBrandId;
                        });
                      },
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppFx.softOverlay(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.textMuted,
                            size: 18.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Bu ürün için şirket markası patenti bulunmuyor. Marka Şirketi ekranından patent alabilirsiniz.',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: 11.sp,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 24.h),

                  // --- Action Buttons ---
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppFx.softOverlay(0.20),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Vazgeç',
                            style: AppTextStyles.button.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              ProductionConfigResult(
                                qualityLevel: _selectedQuality,
                                brandId: _selectedBrandId,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Ürünü Belirle',
                            style: AppTextStyles.button.standardCopyWith(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
  }

  Widget _buildBrandOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: isSelected
                ? (badgeText != null
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.12))
                : AppColors.background.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? (badgeText != null ? AppColors.gold : AppColors.primary)
                  : AppFx.softOverlay(0.12),
              width: isSelected ? 1.5.w : 1.w,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? iconColor : AppColors.textMuted,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTextStyles.body.standardCopyWith(
                              fontSize: 13.sp,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                width: 0.8.w,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: AppTextStyles.caption.standardCopyWith(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.standardCopyWith(
                        fontSize: 10.5.sp,
                        color: AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 18.w,
                height: 18.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (badgeText != null ? AppColors.gold : AppColors.primary)
                        : AppColors.textMuted.withValues(alpha: 0.4),
                    width: 2.w,
                  ),
                  color: isSelected
                      ? (badgeText != null ? AppColors.gold : AppColors.primary)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 12.sp,
                        color: Colors.black,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
