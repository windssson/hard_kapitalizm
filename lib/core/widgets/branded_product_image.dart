import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

class BrandedProductImage extends ConsumerWidget {
  static const String defaultBrandId = '00000000-0000-0000-0000-000000000000';

  final String fileName;
  final String? brandId;
  final String? brandName;
  final String? productId;
  final String? watermarkAssetId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final EdgeInsetsGeometry? padding;
  final Widget? errorWidget;
  final Widget? placeholder;
  final BorderRadius? borderRadius;
  final bool showFrame;
  final double watermarkSizeRatio;
  final double fontSizeRatio;
  final BrandCompanyModel? company;
  final List<BrandCompanyProductModel>? companyProducts;

  const BrandedProductImage({
    super.key,
    required this.fileName,
    this.brandId,
    this.brandName,
    this.productId,
    this.watermarkAssetId,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.padding,
    this.errorWidget,
    this.placeholder,
    this.borderRadius,
    this.showFrame = true,
    this.watermarkSizeRatio = 0.50,
    this.fontSizeRatio = 0.10,
    this.company,
    this.companyProducts,
  });

  bool get _isBranded =>
      brandId != null &&
      brandId!.trim().isNotEmpty &&
      brandId!.trim() != defaultBrandId;

  Color _parseHexColor(String hex, {Color fallback = AppColors.gold}) {
    try {
      var hexColor = hex.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if the current user's brand matches
    final resolvedCompany = company ?? ref.watch(playerBrandCompanyProvider).value;

    final bool isUserBrand =
        _isBranded && resolvedCompany != null && brandId!.trim() == resolvedCompany.id;

    final themeColor = isUserBrand
        ? _parseHexColor(resolvedCompany.themeColor)
        : AppColors.gold;

    final logoId = isUserBrand ? resolvedCompany.logoId : null;
    final displayBrandName = isUserBrand
        ? resolvedCompany.brandName.trim()
        : brandName?.trim();

    // Resolve watermarkAssetId
    String? resolvedWatermark = watermarkAssetId;
    if (resolvedWatermark == null && isUserBrand && productId != null) {
      final List<BrandCompanyProductModel> products = companyProducts ??
          (companyProducts == null ? (ref.watch(playerBrandCompanyProductsProvider).value ?? const []) : const []);
      for (final p in products) {
        if (p.productId == productId) {
          resolvedWatermark = p.watermarkAssetId;
          break;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Resolve size
        final double size =
            width ??
            height ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 60.0);
        final double scale = size / 60.0;

        final radius = borderRadius ?? BorderRadius.circular(12.r * scale);

        final fontSizeValue = size * fontSizeRatio;

        final badgeSize = size * 0.22;
        final badgeOffset = size * 0.055;
        final badgePadding = badgeSize * 0.12;
        final badgeBorderWidth = (size * 0.011).clamp(0.5, 2.5);
        final borderFrameWidth = (size * 0.016).clamp(0.6, 3.0);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: showFrame && _isBranded
                ? Border.all(
                    color: themeColor.withValues(alpha: 0.55),
                    width: borderFrameWidth,
                  )
                : null,
            boxShadow: _isBranded
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.18),
                      blurRadius: 10 * scale,
                      spreadRadius: 0.5 * scale,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: CachedAssetImage(
                    fileName: fileName,
                    fit: fit,
                    errorWidget: errorWidget,
                    placeholder: placeholder,
                  ),
                ),
                if (resolvedWatermark != null && resolvedWatermark.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CachedAssetImage(
                        fileName: resolvedWatermark,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                if (displayBrandName != null && displayBrandName.isNotEmpty)
                  Positioned(
                    bottom: 4 * scale,
                    left: 4 * scale,
                    right: 4 * scale,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          displayBrandName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (fontSizeValue * 0.85).clamp(8.0, 12.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5 * scale,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.95),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isUserBrand && logoId != null)
                  Positioned(
                    top: badgeOffset,
                    left: badgeOffset,
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      padding: EdgeInsets.all(badgePadding),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.4),
                          width: badgeBorderWidth,
                        ),
                      ),
                      child: CachedAssetImage(
                        fileName: logoId,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: const SizedBox.shrink(),
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
}
