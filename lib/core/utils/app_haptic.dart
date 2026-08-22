import 'dart:io';
import 'package:flutter/services.dart';

/// Oyun genelinde dokunsal geri bildirimleri (Haptic Feedback)
/// ve fiziksel donanım titreşimini yöneten merkezi yardımcı sınıf.
class AppHaptic {
  static const MethodChannel _vibeChannel =
      MethodChannel('com.winds.hard_kapitalizm/vibration');

  /// Fiziksel Android titreşim motorunu doğrudan tetikler
  static Future<void> _nativeVibrate(int durationMs, [int amplitude = -1]) async {
    try {
      if (Platform.isAndroid) {
        await _vibeChannel.invokeMethod('vibrate', {
          'duration': durationMs,
          'amplitude': amplitude,
        });
      }
    } catch (_) {}
  }

  /// Hafif dokunuş (örn: tab geçişleri, basit buton tıklamaları, liste elemanına tıklama)
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
      await _nativeVibrate(40, 100);
    } catch (_) {}
  }

  /// Orta seviye dokunuş (örn: başarılı işlem, sepete ekleme, aşama geçişleri)
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
      await _nativeVibrate(100, 180);
    } catch (_) {}
  }

  /// Güçlü dokunuş / Belirgin titreşim (örn: büyük satış, simülasyon bitişi, bina tamamlama)
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
      await _nativeVibrate(350, 255);
    } catch (_) {}
  }

  /// Seçim klik sesi/hissiyatı (örn: sayı klavyesi tıklamaları, switch değişimi)
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
      await _nativeVibrate(30, 80);
    } catch (_) {}
  }

  /// Doğrudan süre belirterek titreşim motorunu çalıştırma
  static Future<void> vibrate([int durationMs = 250]) async {
    try {
      await _nativeVibrate(durationMs, 255);
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
