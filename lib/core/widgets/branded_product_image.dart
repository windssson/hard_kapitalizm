import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';

class BrandedProductImage extends ConsumerWidget {
  final String fileName;
  final String? brandName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final EdgeInsetsGeometry? padding;
  final Widget? errorWidget;
  final Widget? placeholder;
  final BorderRadius? borderRadius;
  final bool showFrame;

  const BrandedProductImage({
    super.key,
    required this.fileName,
    this.brandName,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.padding,
    this.errorWidget,
    this.placeholder,
    this.borderRadius,
    this.showFrame = true,
  });

  bool get _isBranded => brandName != null && brandName!.trim().isNotEmpty;

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
    final radius = borderRadius ?? BorderRadius.circular(12.r);
    
    // Check if the current user's brand matches
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final company = companyAsync.value;
    
    final bool isUserBrand = _isBranded && 
        company != null && 
        brandName!.trim().toLowerCase() == company.brandName.trim().toLowerCase();

    final themeColor = isUserBrand 
        ? _parseHexColor(company.themeColor) 
        : AppColors.gold;

    final logoId = isUserBrand ? company.logoId : null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showFrame && _isBranded
            ? Border.all(color: themeColor.withValues(alpha: 0.55), width: 1.2)
            : null,
        boxShadow: _isBranded
            ? [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  spreadRadius: 0.5,
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
            if (_isBranded)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.52),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                  child: Text(
                    brandName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isUserBrand ? themeColor : AppColors.goldLight,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      shadows: const [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (isUserBrand && logoId != null)
              Positioned(
                top: 4.w,
                left: 4.w,
                child: Container(
                  width: 16.w,
                  height: 16.w,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 0.8),
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
  }
}
