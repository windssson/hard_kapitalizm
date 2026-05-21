import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final authManagerProvider = Provider(
  (ref) => AuthManager(Supabase.instance.client),
);

class AuthManager {
  final SupabaseClient _supabase;

  AuthManager(this._supabase);

  /// Oyuncu oturumunu kontrol eder. Yoksa cihaz kimliğine özel
  /// benzersiz bir e-posta/şifre hesabı ile giriş yapar veya oluşturur.
  Future<void> signInAnonymouslyIfNeeded() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null) {
        // Oturum yok, cihaz kimliği tabanlı hesap ile giriş yap
        final uuid = await _getOrCreateDeviceUUID();
        final email = 'device_$uuid@kapitalizm.com';
        final password = 'pass_${uuid}_secure';

        try {
          // Önce mevcut hesaba giriş yapmayı dene
          final response = await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (response.user != null) {
            await _ensurePlayerRecordExists(response.user!.id);
          }
        } on AuthException catch (e) {
          // Eğer hesap yoksa (örn. geçersiz giriş bilgisi) yeni hesap oluştur
          if (e.message.contains('Invalid login credentials') ||
              e.statusCode == '400' ||
              e.message.contains('confirm')) {
            final response = await _supabase.auth.signUp(
              email: email,
              password: password,
            );
            if (response.user != null) {
              await _ensurePlayerRecordExists(response.user!.id);
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Zaten aktif oturum var, kayıtlı mı kontrol et
        await _ensurePlayerRecordExists(session.user.id);
      }
    } catch (e) {
      throw Exception(
        'Giriş işlemi başarısız: $e\nLütfen Supabase Dashboard -> Authentication -> Providers -> Email ayarının açık (ve Confirm email seçeneğinin kapalı) olduğundan emin olun.',
      );
    }
  }

  /// Cihaza özel benzersiz bir UUID alır veya oluşturup kaydeder.
  Future<String> _getOrCreateDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'device_uuid';
    String? uuid = prefs.getString(key);
    if (uuid != null) {
      return uuid;
    }

    // Cihaz donanım bilgisini almaya çalış
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          // shared_preferences silinmediği sürece UUID sabit kalır.
          uuid = const Uuid().v4();
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          uuid = iosInfo.identifierForVendor ?? const Uuid().v4();
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfo.windowsInfo;
          uuid = windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '');
        } else {
          uuid = const Uuid().v4();
        }
      } else {
        uuid = const Uuid().v4();
      }
    } catch (_) {
      uuid = const Uuid().v4();
    }

    // fallback durumları için UUID'yi shared_preferences'a kaydet
    await prefs.setString(key, uuid);
    return uuid;
  }

  /// Eğer oyuncunun veritabanında kaydı yoksa varsayılan değerlerle yeni kayıt oluşturur.
  Future<void> _ensurePlayerRecordExists(String userId) async {
    try {
      final data = await _supabase
          .from('players')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // Kullanıcı için ilk defa oyuncu kaydı oluşturuluyor
        await _supabase.from('players').insert({
          'id': userId,
          'player_name': 'Oyuncu_${userId.substring(0, 4)}',
          'company_name': 'Yeni Holding',
          'avatar_id': 'ae1.webp',
          'level': 1,
          'experience': 0,
          'cash': 100000, // Başlangıç parası
          'gold': 100, // Başlangıç altını
        });
      }
    } catch (e) {
      throw Exception('Oyuncu kaydı oluşturulamadı veya okunamadı: $e');
    }
  }
}
