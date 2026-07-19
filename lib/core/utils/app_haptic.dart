import 'package:flutter/services.dart';

/// Oyun genelinde dokunsal geri bildirimleri (Haptic Feedback)
/// yöneten merkezi yardımcı sınıf.
class AppHaptic {
  /// Hafif dokunuş (örn: tab geçişleri, basit buton tıklamaları, liste elemanına tıklama)
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Orta seviye dokunuş (örn: başarılı işlem, sepete ekleme, onay pencereleri)
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Güçlü dokunuş (örn: büyük satış, bina inşaatı tamamlama, kredi çekme, ödül alma)
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Seçim klik sesi/hissiyatı (örn: sayı klavyesi tıklamaları, switch değişimi)
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
