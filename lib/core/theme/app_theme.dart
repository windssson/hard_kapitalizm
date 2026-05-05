import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF030712); // En arka plan (çok koyu lacivert/siyah)
  static const Color cardBg = Color(0xFF0A111F);     // Kart arka planları
  static const Color cardBgLight = Color(0xFF111D33); // İkincil kartlar/butonlar
  static const Color navBg = Color(0xFF050A14);      // Alt navigasyon
  
  // Borders
  static const Color border = Color(0xFF1C2A42);     // Standart mavi/gri border
  static const Color borderGold = Color(0xFF6B5120); // Koyu altın border (kartlar için)
  static const Color borderGoldLight = Color(0xFFD4AF37); // Açık altın
  
  // Accents
  static const Color gold = Color(0xFFE5C05C);       // Ana altın sarısı (Metinler/İkonlar)
  static const Color goldDark = Color(0xFFB38D22);
  static const Color goldLight = Color(0xFFFDE47F);  // Açık altın sarısı
  static const Color green = Color(0xFF00E676);      // Pozitif değerler
  static const Color red = Color(0xFFFF5252);        // Negatif/Uyarılar
  static const Color blue = Color(0xFF42A5F5);       // Mavi detaylar
  static const Color diamond = Color(0xFF00E5FF);    // Elmas rengi
  
  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

class AppTextStyles {
  static TextStyle get h1 => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24.sp,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get h2 => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18.sp,
    fontWeight: FontWeight.bold,
  );
  
  static TextStyle get titleGold => TextStyle(
    color: AppColors.gold,
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get body => TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12.sp,
  );

  static TextStyle get statValue => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28.sp,
    fontWeight: FontWeight.w800,
  );
}
