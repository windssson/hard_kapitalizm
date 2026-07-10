import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_icons.dart';

export 'app_icons.dart';

class AppColors {
  // ── 5 temel renk ─────────────────────────────────────────────────────
  static const Color background = Color(0xFF03131F);
  static const Color cardBg = Color(0xFF08263A);
  static const Color successCore = Color(0xFF57D94C);
  static const Color dangerCore = Color(0xFFF04B3A);
  static const Color accent = Color(0xFFF3B52A);

  // ── Arka plan / yüzey renkleri (5-renk sisteminden türetildi) ─────
  static Color get primary => background;
  static Color get secondary =>
      Color.alphaBlend(cardBg.withValues(alpha: 0.35), background);
  static Color get cardBgLight =>
      Color.alphaBlend(cardBg.withValues(alpha: 0.65), background);
  static Color get navBg => cardBg;
  static Color get panel => cardBg;
  static Color get panelMuted => cardBgLight;

  // ── Kenarlık renkleri (5-renk sisteminden türetildi) ──────────────
  static Color get cardBorder =>
      Color.alphaBlend(accent.withValues(alpha: 0.12), secondary);
  static Color get border => cardBorder;
  static Color get borderGold =>
      Color.alphaBlend(accent.withValues(alpha: 0.55), cardBg);
  static Color get borderGoldLight =>
      Color.alphaBlend(accent.withValues(alpha: 0.32), cardBg);

  // ── Vurgu renk alias'ları (5-renk sistemine bağlı) ───────────────
  static Color get gold => accent;
  static Color get goldDark =>
      Color.alphaBlend(dangerCore.withValues(alpha: 0.18), accent);
  static Color get goldLight =>
      Color.alphaBlend(cardBg.withValues(alpha: 0.45), accent);
  static Color get green => successCore;
  static Color get red => dangerCore;
  static Color get blue => accent;
  static Color get diamond => accent;
  static Color get orange => accent;
  static Color get purple => accent;
  static Color get teal => accent;

  // ── Metin / yardımcı renkler (5-renk sisteminden türetildi) ───────
  static Color get textPrimary => AppTextColors.primary;
  static Color get textSecondary => AppTextColors.secondary;
  static Color get textMuted => AppTextColors.muted;
  static Color get textOnAccent => AppTextColors.onAction;
  static Color get textPositive => AppTextColors.positive;
  static Color get textNegative => AppTextColors.negative;
  static Color get textPremium => AppTextColors.premium;
  static Color get white =>
      HSLColor.fromColor(cardBg).withLightness(0.98).toColor();
  static Color get black => background;
  static Color get transparent => cardBg.withValues(alpha: 0);

  static Color get success => successCore;
  static Color get danger => red;
  static Color get warning => accent;
  static Color get info => gold;

  static Color get badgeBlue => accent;
  static Color get badgeRed => dangerCore;
  static Color get badgeGreen => successCore;
  static Color get badgeLime => successCore;
  static Color get badgeSlate => textMuted;
  static Color get badgeOrange => accent;
  static Color get badgeDeepOrange => accent;
  static Color get badgeCyan => accent;
  static Color get badgePurple => accent;
  static Color get badgeTeal => accent;
  static Color get badgeAmber => accent;
}

class AppTextColors {
  static Color _tone(Color source, double lightness) =>
      HSLColor.fromColor(source).withLightness(lightness).toColor();

  // All roles meet at least 4.5:1 contrast on background and card surfaces.
  static Color get primary => _tone(AppColors.cardBg, 0.94);
  static Color get secondary =>
      Color.alphaBlend(primary.withValues(alpha: 0.70), AppColors.cardBg);
  static Color get muted =>
      Color.alphaBlend(primary.withValues(alpha: 0.55), AppColors.cardBg);
  static Color get positive => AppColors.successCore;
  static Color get negative => _tone(AppColors.dangerCore, 0.62);
  static Color get premium => AppColors.accent;
  static Color get onAction => AppColors.background;

  static Color resolve(Color color) {
    final opaque = color.withValues(alpha: 1);

    if (opaque == primary || opaque == AppColors.dangerCore) {
      return opaque == primary ? primary : negative;
    }
    if (opaque == secondary) return secondary;
    if (opaque == muted) return muted;
    if (opaque == onAction || opaque == AppColors.background) return onAction;
    if (opaque == AppColors.white) return primary;
    if (opaque == positive || opaque == AppColors.successCore) return positive;
    if (opaque == negative) return negative;
    if (opaque == premium || opaque == AppColors.accent) return premium;
    if (opaque == AppColors.cardBg || opaque == AppColors.cardBgLight) {
      return primary;
    }

    final hue = HSLColor.fromColor(opaque).hue;
    if (hue >= 70 && hue <= 170) return positive;
    if (hue <= 35 || hue >= 335) return negative;
    return premium;
  }
}

class AppFx {
  static Color scrim([double alpha = 0.60]) =>
      AppColors.black.withValues(alpha: alpha);

  static Color shadow([double alpha = 0.22]) =>
      AppColors.black.withValues(alpha: alpha);

  static Color softOverlay([double alpha = 0.08]) =>
      AppColors.white.withValues(alpha: alpha);

  static Color goldWash([double alpha = 0.12]) =>
      AppColors.gold.withValues(alpha: alpha);

  static Color panelWash([double alpha = 0.40]) =>
      AppColors.black.withValues(alpha: alpha);
}

// Standart kart köşe ovalliği
const double kCardRadius = 14.0;

class AppTypography {
  // Register a custom family in pubspec.yaml, then change only this value.
  static const String fontFamily = 'Inter';

  // Changes every text size in the game while preserving the type scale.
  static const double scale = 1.0;

  static String? get resolvedFontFamily =>
      fontFamily == 'system' ? null : fontFamily;

  static double _scaled(double size) => (size * scale).sp;

  static double get micro => _scaled(8);
  static double get caption => _scaled(9);
  static double get label => _scaled(10);
  static double get bodySmall => _scaled(11);
  static double get body => _scaled(12);
  static double get bodyLarge => _scaled(13);
  static double get title => _scaled(14);
  static double get titleLarge => _scaled(16);
  static double get headline => _scaled(18);
  static double get displaySmall => _scaled(20);
  static double get display => _scaled(24);
  static double get hero => _scaled(28);
  static double get heroLarge => _scaled(36);
}

class AppTextStyles {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamily: AppTypography.resolvedFontFamily,
    );
  }

  // 1. Large Title: istatistik / hero değerler
  static TextStyle get largeTitle => _base(
    color: AppColors.textPrimary,
    size: AppTypography.display,
    weight: FontWeight.bold,
  );

  // 2. Title: kart başlıkları
  static TextStyle get title => _base(
    color: AppColors.textPrimary,
    size: AppTypography.title,
    weight: FontWeight.bold,
  );

  // 3. Body: açıklama metinleri
  static TextStyle get body => _base(
    color: AppColors.textSecondary,
    size: AppTypography.body,
    weight: FontWeight.w400,
  );

  // 4. Caption: küçük etiketler
  static TextStyle get caption => _base(
    color: AppColors.textMuted,
    size: AppTypography.caption,
    weight: FontWeight.w400,
  );

  static TextStyle get label => _base(
    color: AppColors.textSecondary,
    size: AppTypography.label,
    weight: FontWeight.w700,
  );

  static TextStyle get button => _base(
    color: AppColors.textOnAccent,
    size: AppTypography.body,
    weight: FontWeight.w800,
    letterSpacing: 0.3,
  );

  static TextStyle get overline => _base(
    color: AppColors.textMuted,
    size: AppTypography.micro,
    weight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  // --- Aliases ---
  static TextStyle get h1 => largeTitle;
  static TextStyle get h2 =>
      largeTitle.copyWith(fontSize: AppTypography.headline);
  static TextStyle get titleGold => title.copyWith(
    color: AppTextColors.premium,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  static TextStyle get titleBold =>
      title.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2);
  static TextStyle get titleGoldBold => title.copyWith(
    color: AppTextColors.premium,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
  );
  static TextStyle get subtitleBold =>
      body.copyWith(fontWeight: FontWeight.w900, fontSize: AppTypography.label);
  static TextStyle get statValue => largeTitle.copyWith(
    fontSize: AppTypography.hero,
    fontWeight: FontWeight.w800,
  );
  static TextStyle get xpText => caption.copyWith(
    color: AppTextColors.primary,
    fontWeight: FontWeight.w700,
    fontSize: AppTypography.micro,
  );
  static TextStyle get badgeText => caption.copyWith(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w900,
    fontSize: AppTypography.caption,
    height: 1,
  );
  static TextStyle get resourceValue => title.copyWith(
    fontSize: AppTypography.bodySmall,
    fontWeight: FontWeight.w800,
  );
  static TextStyle get actionButtonText => caption.copyWith(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w700,
    fontSize: AppTypography.micro,
  );
  static TextStyle get input => body.copyWith(color: AppColors.textPrimary);
  static TextStyle get sectionTitle =>
      titleBold.copyWith(fontSize: AppTypography.titleLarge);
  static TextStyle get metric =>
      h2.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary);

  static TextTheme get materialTextTheme => TextTheme(
    displayLarge: largeTitle.copyWith(fontSize: AppTypography.heroLarge),
    displayMedium: largeTitle.copyWith(fontSize: AppTypography.hero),
    displaySmall: largeTitle,
    headlineLarge: h2,
    headlineMedium: sectionTitle,
    headlineSmall: title,
    titleLarge: sectionTitle,
    titleMedium: title,
    titleSmall: label,
    bodyLarge: body.copyWith(fontSize: AppTypography.bodyLarge),
    bodyMedium: body,
    bodySmall: body.copyWith(fontSize: AppTypography.bodySmall),
    labelLarge: button,
    labelMedium: label,
    labelSmall: caption,
  );
}

extension AppTextStyleStandard on TextStyle {
  TextStyle standardCopyWith({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return copyWith(
      color: color == null ? null : AppTextColors.resolve(color),
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }
}

class AppStyleGuide {
  static const String usage = '''
Tasarim kurali:
- Once 5 ana rol kullanilir: background, cardBg, successCore, dangerCore, gold.
- Renkler yalnizca AppColors / AppFx uzerinden secilmeli.
- Yazi stilleri yalnizca AppTextStyles uzerinden gelmeli.
- Ekran icinde dogrudan Colors.* ve ham TextStyle(...) yazilmamali.
- Yeni bir ton gerekiyorsa once bu dosyaya eklenmeli, sonra kullanilmali.
''';
}

class AppColorPresets {
  static Color badge(String key) {
    switch (key) {
      case 'blue':
        return AppColors.badgeBlue;
      case 'red':
        return AppColors.badgeRed;
      case 'green':
        return AppColors.badgeGreen;
      case 'lime':
        return AppColors.badgeLime;
      case 'slate':
        return AppColors.badgeSlate;
      case 'orange':
        return AppColors.badgeOrange;
      case 'deepOrange':
        return AppColors.badgeDeepOrange;
      case 'cyan':
        return AppColors.badgeCyan;
      case 'purple':
        return AppColors.badgePurple;
      case 'teal':
        return AppColors.badgeTeal;
      case 'amber':
      default:
        return AppColors.badgeAmber;
    }
  }
}

class AppDecorations {
  // ─────────────────────────────────────────────
  // 1. STANDART KART
  //    Renk: cardBg | Çerçeve: cardBorder | Köşe: kCardRadius
  //    Sadece durum kartları [accentColor] alır.
  // ─────────────────────────────────────────────
  static BoxDecoration card({Color? accentColor}) {
    return BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(kCardRadius.r),
      border: Border.all(
        color: accentColor ?? AppColors.cardBorder,
        width: 1.w,
      ),
      boxShadow: [
        BoxShadow(
          color: AppFx.shadow(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 2. ROZET / İKON SARICI
  // ─────────────────────────────────────────────
  static BoxDecoration badge({
    Color? bgColor,
    Color? borderColor,
    double? radius,
    bool isCircle = false,
  }) {
    return BoxDecoration(
      color: bgColor ?? AppColors.gold.withValues(alpha: 0.08),
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : BorderRadius.circular(radius ?? 8.r),
      border: Border.all(
        color: borderColor ?? AppColors.cardBorder,
        width: 1.w,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 3. ALT PANEL (Bottom Sheet)
  // ─────────────────────────────────────────────
  static BoxDecoration bottomSheet([double? radius]) {
    return BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius ?? 24.r)),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: AppFx.shadow(0.25),
          blurRadius: 12,
          offset: const Offset(0, -3),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 4. İLERLEME ÇUBUĞU
  // ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
  // Aliases (aktif kullanımda olanlar)
  // ─────────────────────────────────────────────
  static BoxDecoration premiumCard([Color? accentColor, double? radius]) =>
      card(accentColor: accentColor);

  static BoxDecoration glowingAction([Color? accentColor, double? radius]) =>
      card(accentColor: accentColor ?? AppColors.gold.withValues(alpha: 0.45));

  static BoxDecoration panelGlass([double? radius]) => bottomSheet(radius);

  static BoxDecoration topBarInner() => BoxDecoration(
    color: AppColors.cardBg,
    border: Border.all(color: AppColors.transparent),
  );

  static BoxDecoration levelBadge() => badge(
    bgColor: AppColors.cardBgLight,
    borderColor: AppColors.cardBorder,
    radius: 12.r,
  );

  static BoxDecoration resourceIconWrapper() => badge(
    bgColor: AppFx.panelWash(0.25),
    borderColor: AppColors.transparent,
    radius: 8.r,
  );

  static BoxDecoration resourceActionButton() => badge(
    bgColor: AppColors.gold.withValues(alpha: 0.08),
    borderColor: AppColors.cardBorder,
    radius: 8.r,
  );

  static BoxDecoration secondaryTopBar(double height) => BoxDecoration(
    color: AppColors.cardBg,
    border: Border(
      bottom: BorderSide(color: AppColors.cardBorder, width: 1.h),
    ),
  );

  static BoxDecoration backButton() => badge(
    bgColor: AppColors.cardBg,
    borderColor: AppColors.cardBorder,
    isCircle: true,
  );

  static BoxDecoration compactCurrency(Color color) => badge(
    bgColor: AppColors.background.withValues(alpha: 0.4),
    borderColor: AppColors.cardBorder,
    radius: 12.r,
  );
}

class AppTheme {
  static ThemeData buildTheme() {
    final base = ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        brightness: Brightness.light,
        primary: AppColors.green,
        secondary: AppColors.gold,
        surface: AppColors.cardBg,
      ),
      fontFamily: AppTypography.resolvedFontFamily,
      textTheme: AppTextStyles.materialTextTheme,
      useMaterial3: true,
    );

    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      canvasColor: AppColors.background,
      cardColor: AppColors.cardBg,
      iconTheme: IconThemeData(
        color: AppColors.textSecondary,
        size: AppIconSizes.regular,
      ),
      primaryIconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: AppIconSizes.regular,
      ),
      dividerColor: AppColors.cardBorder,
      disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
      hintColor: AppColors.textMuted,
      shadowColor: AppFx.shadow(0.22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: AppColors.background,
        circularTrackColor: AppColors.cardBgLight,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.cardBorder.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionColor: AppColors.gold.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.gold,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardBg,
        contentTextStyle: AppTextStyles.body.standardCopyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(color: AppColors.cardBorder, width: 1.w),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.cardBgLight;
            }
            return AppColors.green;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textMuted;
            }
            return AppColors.textOnAccent;
          }),
          overlayColor: WidgetStatePropertyAll(
            AppColors.green.withValues(alpha: 0.10),
          ),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(0, 44.h)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.disabled)
                ? AppColors.cardBorder
                : AppColors.green.withValues(alpha: 0.32);
            return BorderSide(color: color, width: 1.w);
          }),
          textStyle: WidgetStatePropertyAll(AppTextStyles.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
          overlayColor: WidgetStatePropertyAll(
            AppColors.gold.withValues(alpha: 0.08),
          ),
          minimumSize: WidgetStatePropertyAll(Size(0, 42.h)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.disabled)
                ? AppColors.cardBorder.withValues(alpha: 0.45)
                : AppColors.cardBorder;
            return BorderSide(color: color, width: 1.w);
          }),
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.label.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySmall,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.gold),
          overlayColor: WidgetStatePropertyAll(
            AppColors.gold.withValues(alpha: 0.08),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.label.standardCopyWith(color: AppColors.gold),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        hintStyle: AppTextStyles.body.standardCopyWith(
          color: AppColors.textMuted,
        ),
        labelStyle: AppTextStyles.body.standardCopyWith(
          color: AppColors.textSecondary,
        ),
        helperStyle: AppTextStyles.caption.standardCopyWith(
          fontSize: AppTypography.label,
        ),
        errorStyle: AppTextStyles.caption.standardCopyWith(
          color: AppColors.red,
          fontSize: AppTypography.label,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.cardBorder, width: 1.w),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.cardBorder, width: 1.w),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.8),
            width: 1.2.w,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.red, width: 1.w),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.red, width: 1.2.w),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: AppColors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.label.standardCopyWith(
          color: AppColors.goldLight,
          fontWeight: FontWeight.w900,
          fontSize: AppTypography.bodySmall,
        ),
        unselectedLabelStyle: AppTextStyles.label.standardCopyWith(
          color: AppColors.textSecondary,
          fontSize: AppTypography.label,
        ),
      ),
    );
  }
}

class AppButtonStyles {
  static ButtonStyle primary({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.green,
      foregroundColor: foregroundColor ?? AppColors.textOnAccent,
      side: BorderSide(
        color: borderColor ?? AppColors.green.withValues(alpha: 0.35),
        width: 1.w,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      elevation: 0,
      textStyle: AppTextStyles.button,
    );
  }

  static ButtonStyle outline({
    Color? foregroundColor,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? AppColors.textPrimary,
      backgroundColor: backgroundColor,
      side: BorderSide(color: borderColor ?? AppColors.cardBorder, width: 1.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      textStyle: AppTextStyles.label.standardCopyWith(
        color: foregroundColor ?? AppColors.textPrimary,
      ),
    );
  }
}

class AppInputStyles {
  static InputDecoration search({
    required String hintText,
    Widget? prefixIcon,
    Color? fillColor,
    Color? borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      fillColor: fillColor,
      filled: fillColor != null,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.cardBorder,
          width: 1.w,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: borderColor ?? AppColors.cardBorder,
          width: 1.w,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1.w,
        ),
      ),
    );
  }
}
