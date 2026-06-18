import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';

class BrandedProductImage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12.r);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showFrame && _isBranded
            ? Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.1)
            : null,
        boxShadow: _isBranded
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.14),
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
                        Colors.black.withValues(alpha: 0.42),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                  child: Text(
                    brandName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.goldLight,
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
          ],
        ),
      ),
    );
  }
}
