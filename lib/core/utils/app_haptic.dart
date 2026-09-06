import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyun genelinde dokunsal geri bildirimleri (Haptic Feedback)
/// ve fiziksel donanım titreşimini yöneten merkezi yardımcı sınıf.
class AppHaptic {
  static const String _prefKey = 'app_haptics_enabled';
  static const MethodChannel _vibeChannel =
      MethodChannel('com.winds.hard_kapitalizm/vibration');

  static bool _enabled = true;

  /// Mevcut haptik açık/kapalı durumu
  static bool get isEnabled => _enabled;

  /// Uygulama başlarken tercihi yükler
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  /// Titreşimi etkinleştirir veya devre dışı bırakır
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// Fiziksel Android titreşim motorunu doğrudan tetikler
  static Future<void> _nativeVibrate(int durationMs, [int amplitude = -1]) async {
    if (!_enabled) return;
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
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
      await _nativeVibrate(40, 100);
    } catch (_) {}
  }

  /// Orta seviye dokunuş (örn: başarılı işlem, sepete ekleme, aşama geçişleri)
  static Future<void> medium() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await _nativeVibrate(100, 180);
    } catch (_) {}
  }

  /// Güçlü dokunuş / Belirgin titreşim (örn: büyük satış, simülasyon bitişi, bina tamamlama)
  static Future<void> heavy() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await _nativeVibrate(350, 255);
    } catch (_) {}
  }

  /// Seçim klik sesi/hissiyatı (örn: sayı klavyesi tıklamaları, switch değişimi)
  static Future<void> selection() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.selectionClick();
      await _nativeVibrate(30, 80);
    } catch (_) {}
  }

  /// Doğrudan süre belirterek titreşim motorunu çalıştırma
  static Future<void> vibrate([int durationMs = 250]) async {
    if (!_enabled) return;
    try {
      await _nativeVibrate(durationMs, 255);
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}

