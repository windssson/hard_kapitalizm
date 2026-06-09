import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final authManagerProvider = Provider(
  (ref) => AuthManager(Supabase.instance.client),
);

class AuthManager {
  static const _deviceUuidKey = 'device_uuid';
  static const _secureStorage = FlutterSecureStorage();

  final SupabaseClient _supabase;

  AuthManager(this._supabase);

  /// Oyuncu oturumunu kontrol eder. Yoksa cihaz kimligine ozel
  /// benzersiz bir e-posta/sifre hesabi ile giris yapar veya olusturur.
  Future<void> signInAnonymouslyIfNeeded() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null) {
        final uuid = await _getOrCreateDeviceUUID();
        final email = 'device_$uuid@kapitalizm.com';
        final password = 'pass_${uuid}_secure';

        try {
          final response = await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (response.user != null) {
            await _ensurePlayerRecordExists(response.user!.id);
          }
        } on AuthException catch (e) {
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
      }
    } catch (e) {
      throw Exception(
        'Giris islemi basarisiz: $e\nLutfen Supabase Dashboard -> Authentication -> Providers -> Email ayarinin acik (ve Confirm email seceneginin kapali) oldugundan emin olun.',
      );
    }
  }

  Future<String> _getOrCreateDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final secureUuid = await _secureStorage.read(key: _deviceUuidKey);
      if (secureUuid != null && secureUuid.isNotEmpty) {
        final cachedUuid = prefs.getString(_deviceUuidKey);
        if (cachedUuid != secureUuid) {
          await prefs.setString(_deviceUuidKey, secureUuid);
        }
        return secureUuid;
      }
    } catch (_) {
      // Secure storage kullanilamiyorsa eski/yerel yedek degere dus.
    }

    final legacyUuid = prefs.getString(_deviceUuidKey);
    if (legacyUuid != null && legacyUuid.isNotEmpty) {
      try {
        await _secureStorage.write(key: _deviceUuidKey, value: legacyUuid);
      } catch (_) {
        // Guvenli depoya tasima basarisiz olsa da mevcut hesabi koru.
      }
      return legacyUuid;
    }

    final uuid = const Uuid().v4();

    try {
      await _secureStorage.write(key: _deviceUuidKey, value: uuid);
    } catch (_) {
      // Bazi platformlarda secure storage gecici olarak kullanilamayabilir.
    }

    await prefs.setString(_deviceUuidKey, uuid);
    return uuid;
  }

  Future<void> _ensurePlayerRecordExists(String userId) async {
    try {
      await _supabase.rpc(
        'ensure_player_record_exists',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      throw Exception('Oyuncu kaydi olusturulamadi veya okunamadi: $e');
    }
  }
}
