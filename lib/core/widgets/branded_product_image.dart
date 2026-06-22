import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';

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
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final company = companyAsync.value;

    final bool isUserBrand =
        _isBranded && company != null && brandId!.trim() == company.id;

    final themeColor = isUserBrand
        ? _parseHexColor(company.themeColor)
        : AppColors.gold;

    final logoId = isUserBrand ? company.logoId : null;
    final displayBrandName = isUserBrand
        ? company.brandName.trim()
        : brandName?.trim();

    // Resolve watermarkAssetId
    String? resolvedWatermark = watermarkAssetId;
    if (resolvedWatermark == null && isUserBrand && productId != null) {
      final productsAsync = ref.watch(playerBrandCompanyProductsProvider);
      final products = productsAsync.value ?? [];
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

        final watermarkSize = size * watermarkSizeRatio;
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
                if ((resolvedWatermark != null &&
                        resolvedWatermark.isNotEmpty) ||
                    (displayBrandName != null && displayBrandName.isNotEmpty))
                  Positioned(
                    top: badgeOffset,
                    right: badgeOffset,
                    child: IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (resolvedWatermark != null &&
                              resolvedWatermark.isNotEmpty)
                            CachedAssetImage(
                              fileName: resolvedWatermark,
                              width: watermarkSize,
                              height: watermarkSize,
                              fit: BoxFit.contain,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            )
                          else
                            SizedBox(
                              width: watermarkSize,
                              height: watermarkSize,
                            ),
                          if (displayBrandName != null &&
                              displayBrandName.isNotEmpty)
                            Transform.translate(
                              offset: Offset(
                                watermarkSize * 0.08,
                                -watermarkSize * 0.08,
                              ),
                              child: Transform.rotate(
                                angle: 3.1415926535 / 4,
                                child: Text(
                                  displayBrandName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: fontSizeValue,
                                    fontWeight: FontWeight.w900,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
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
