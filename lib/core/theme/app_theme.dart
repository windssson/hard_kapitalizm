import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF030712);
  static const Color cardBg = Color(0xFF0A111F);
  static const Color cardBgLight = Color(0xFF111D33);
  static const Color navBg = Color(0xFF050A14);

  // Borders
  static const Color cardBorder = Color(0xFF1E2E46); // Tek standart kenarlık
  static const Color border = Color(0xFF1C2A42);     // Legacy alias — cardBorder ile aynı tona yakın
  static const Color borderGold = Color(0xFF6B5120); // Altın kenarlık (splash + özel durumlar)
  static const Color borderGoldLight = Color(0xFFD4AF37);

  // Accents
  static const Color gold = Color(0xFFE5C05C);
  static const Color goldDark = Color(0xFFB38D22);
  static const Color goldLight = Color(0xFFFDE47F);
  static const Color green = Color(0xFF00E676);
  static const Color red = Color(0xFFFF5252);
  static const Color blue = Color(0xFF42A5F5);
  static const Color diamond = Color(0xFF00E5FF);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

// Standart kart köşe ovalliği
const double kCardRadius = 14.0;

class AppTextStyles {
  // 1. Large Title: istatistik / hero değerler
  static TextStyle get largeTitle => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24.sp,
    fontWeight: FontWeight.bold,
  );

  // 2. Title: kart başlıkları
  static TextStyle get title => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14.sp,
    fontWeight: FontWeight.bold,
  );

  // 3. Body: açıklama metinleri
  static TextStyle get body => TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12.sp,
  );

  // 4. Caption: küçük etiketler
  static TextStyle get caption => TextStyle(
    color: AppColors.textMuted,
    fontSize: 9.sp,
  );

  // --- Aliases ---
  static TextStyle get h1 => largeTitle;
  static TextStyle get h2 => largeTitle.copyWith(fontSize: 18.sp);
  static TextStyle get titleGold => title.copyWith(color: AppColors.gold, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static TextStyle get titleBold => title.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2);
  static TextStyle get titleGoldBold => title.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w900, letterSpacing: 1.1);
  static TextStyle get subtitleBold => body.copyWith(fontWeight: FontWeight.w900, fontSize: 10.sp);
  static TextStyle get statValue => largeTitle.copyWith(fontSize: 28.sp, fontWeight: FontWeight.w800);
  static TextStyle get xpText => caption.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.94), fontWeight: FontWeight.w700, fontSize: 7.8.sp);
  static TextStyle get badgeText => caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 9.sp, height: 1);
  static TextStyle get resourceValue => title.copyWith(fontSize: 11.4.sp, fontWeight: FontWeight.w800);
  static TextStyle get actionButtonText => caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 6.8.sp);
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
          color: Colors.black.withValues(alpha: 0.2),
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
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, -3),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 4. İLERLEME ÇUBUĞU
  // ─────────────────────────────────────────────
  static BoxDecoration progressTrack() => BoxDecoration(
    color: Colors.black.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(999.r),
    border: Border.all(color: AppColors.cardBorder, width: 1.w),
  );

  static BoxDecoration progressFill() => const BoxDecoration(
    gradient: LinearGradient(
      colors: [AppColors.goldDark, AppColors.gold, AppColors.goldLight],
    ),
  );

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
    border: Border.all(color: Colors.transparent),
  );

  static BoxDecoration levelBadge() => badge(
    bgColor: AppColors.cardBgLight,
    borderColor: AppColors.cardBorder,
    radius: 12.r,
  );

  static BoxDecoration resourceIconWrapper() => badge(
    bgColor: Colors.black.withValues(alpha: 0.25),
    borderColor: Colors.transparent,
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
