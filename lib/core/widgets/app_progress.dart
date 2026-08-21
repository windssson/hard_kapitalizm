import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

enum AppProgressKind {
  standard,
  positive,
  capacity,
  stock,
  danger,
  neutral,
  onAction,
}

enum AppProgressSize { compact, regular, large }

abstract final class AppProgressTokens {
  static const Duration animationDuration = Duration(milliseconds: 280);

  static double height(AppProgressSize size) => switch (size) {
    AppProgressSize.compact => 5.h,
    AppProgressSize.regular => 8.h,
    AppProgressSize.large => 10.h,
  };

  static double loadingSize(AppProgressSize size) => switch (size) {
    AppProgressSize.compact => 18.w,
    AppProgressSize.regular => 28.w,
    AppProgressSize.large => 40.w,
  };

  static double loadingStroke(AppProgressSize size) => switch (size) {
    AppProgressSize.compact => 2.w,
    AppProgressSize.regular => 2.5.w,
    AppProgressSize.large => 3.w,
  };

  static Color track(AppProgressKind kind) => switch (kind) {
    AppProgressKind.onAction => AppColors.background.withValues(alpha: 0.28),
    _ => AppColors.cardBgLight,
  };

  static Color fill(AppProgressKind kind, double? value) => switch (kind) {
    AppProgressKind.positive => AppColors.green,
    AppProgressKind.capacity => _capacityColor(value ?? 0),
    AppProgressKind.stock => _stockColor(value ?? 0),
    AppProgressKind.danger => AppColors.red,
    AppProgressKind.neutral => AppColors.textSecondary,
    AppProgressKind.onAction => AppColors.textOnAccent,
    AppProgressKind.standard => AppColors.gold,
  };

  static AppProgressKind kindFromColor(Color color) {
    final opaque = color.withValues(alpha: 1);
    if (opaque == AppColors.green || opaque == AppColors.success) {
      return AppProgressKind.positive;
    }
    if (opaque == AppColors.red || opaque == AppColors.danger) {
      return AppProgressKind.danger;
    }
    if (opaque == AppColors.textOnAccent || opaque == AppColors.background) {
      return AppProgressKind.onAction;
    }
    if (opaque == AppColors.textSecondary || opaque == AppColors.textMuted) {
      return AppProgressKind.neutral;
    }
    return AppProgressKind.standard;
  }

  static Color _capacityColor(double value) {
    if (value >= 0.90) return AppColors.red;
    if (value >= 0.75) return AppColors.gold;
    return AppColors.green;
  }

  static Color _stockColor(double value) {
    if (value <= 0.25) return AppColors.red;
    if (value <= 0.60) return AppColors.gold;
    return AppColors.green;
  }
}

class AppLoadingIndicator extends StatelessWidget {
  final double? value;
  final AppProgressKind kind;
  final AppProgressSize size;
  final double? strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  const AppLoadingIndicator({
    super.key,
    this.value,
    this.kind = AppProgressKind.standard,
    this.size = AppProgressSize.regular,
    this.strokeWidth,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  const AppLoadingIndicator.compact({
    super.key,
    this.value,
    this.kind = AppProgressKind.onAction,
    this.strokeWidth,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  }) : size = AppProgressSize.compact;

  @override
  Widget build(BuildContext context) {
    final resolvedKind = color == null
        ? kind
        : AppProgressTokens.kindFromColor(color!);
    final dimension = AppProgressTokens.loadingSize(size);

    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        value: value?.clamp(0.0, 1.0),
        strokeWidth: strokeWidth ?? AppProgressTokens.loadingStroke(size),
        color: valueColor == null
            ? AppProgressTokens.fill(resolvedKind, value)
            : null,
        backgroundColor:
            backgroundColor ?? AppProgressTokens.track(resolvedKind),
        valueColor: valueColor,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      ),
    );
  }
}

class AppProgressBar extends StatelessWidget {
  final double? value;
  final AppProgressKind kind;
  final AppProgressSize size;
  final double? minHeight;
  final Color? color;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel;
  final String? semanticsValue;

  const AppProgressBar({
    super.key,
    required this.value,
    this.kind = AppProgressKind.standard,
    this.size = AppProgressSize.regular,
    this.minHeight,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  });

  const AppProgressBar.capacity({
    super.key,
    required this.value,
    this.size = AppProgressSize.regular,
    this.minHeight,
    this.backgroundColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  }) : kind = AppProgressKind.capacity,
       color = null,
       valueColor = null;

  const AppProgressBar.stock({
    super.key,
    required this.value,
    this.size = AppProgressSize.regular,
    this.minHeight,
    this.backgroundColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  }) : kind = AppProgressKind.stock,
       color = null,
       valueColor = null;

  const AppProgressBar.positive({
    super.key,
    required this.value,
    this.size = AppProgressSize.regular,
    this.minHeight,
    this.backgroundColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  }) : kind = AppProgressKind.positive,
       color = null,
       valueColor = null;

  @override
  Widget build(BuildContext context) {
    final safeValue = value?.clamp(0.0, 1.0);
    final legacyColor = color ?? valueColor?.value;
    final resolvedKind = legacyColor == null
        ? kind
        : AppProgressTokens.kindFromColor(legacyColor);
    final radius = borderRadius ?? BorderRadius.circular(999.r);

    return ClipRRect(
      borderRadius: radius,
      child: LinearProgressIndicator(
        value: safeValue,
        minHeight: minHeight ?? AppProgressTokens.height(size),
        color: valueColor == null
            ? AppProgressTokens.fill(resolvedKind, safeValue)
            : null,
        backgroundColor:
            backgroundColor ?? AppProgressTokens.track(resolvedKind),
        valueColor: valueColor,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      ),
    );
  }
}

class AppProgressRing extends StatelessWidget {
  final double value;
  final AppProgressKind kind;
  final AppProgressSize size;
  final double? diameter;
  final double? strokeWidth;
  final String? semanticsLabel;

  const AppProgressRing({
    super.key,
    required this.value,
    this.kind = AppProgressKind.standard,
    this.size = AppProgressSize.regular,
    this.diameter,
    this.strokeWidth,
    this.semanticsLabel,
  });

  const AppProgressRing.stock({
    super.key,
    required this.value,
    this.size = AppProgressSize.regular,
    this.diameter,
    this.strokeWidth,
    this.semanticsLabel,
  }) : kind = AppProgressKind.stock;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: diameter ?? AppProgressTokens.loadingSize(size),
      child: CircularProgressIndicator(
        value: safeValue,
        strokeWidth: strokeWidth ?? AppProgressTokens.loadingStroke(size),
        color: AppProgressTokens.fill(kind, safeValue),
        backgroundColor: AppProgressTokens.track(kind),
        semanticsLabel: semanticsLabel,
        semanticsValue: '${(safeValue * 100).round()}%',
      ),
    );
  }
}
