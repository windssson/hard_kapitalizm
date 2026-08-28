import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildFallback(context);
    }

    final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

    // Automatic thumbnail memory cache bounds to prevent OOM / RAM bloat
    final autoMemCacheW = memCacheWidth ??
        (width != null && width! > 0
            ? (width! * devicePixelRatio).round().clamp(16, 2048)
            : null);

    final autoMemCacheH = memCacheHeight ??
        (height != null && height! > 0
            ? (height! * devicePixelRatio).round().clamp(16, 2048)
            : null);

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: autoMemCacheW,
      memCacheHeight: autoMemCacheH,
      placeholder: (context, url) =>
          placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: Center(
              child: SizedBox(
                width: ((width ?? 24) * 0.5).clamp(12, 24),
                height: ((height ?? 24) * 0.5).clamp(12, 24),
                child: AppLoadingIndicator(color: AppColors.gold),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildFallback(context),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildFallback(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          AppIcons.person,
          size: ((width ?? 24) * 0.6).clamp(14, 40),
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
