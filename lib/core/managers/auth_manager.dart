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

  /// Oyuncu oturumunu kontrol eder. Yoksa cihaz kimligine ozel
  /// benzersiz bir e-posta/sifre hesabÄ± ile giris yapar veya olusturur.
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
      } else {
        await _ensurePlayerRecordExists(session.user.id);
      }
    } catch (e) {
      throw Exception(
        'Giris islemi basarisiz: $e\nLutfen Supabase Dashboard -> Authentication -> Providers -> Email ayarinin acik (ve Confirm email seceneginin kapali) oldugundan emin olun.',
      );
    }
  }

  Future<String> _getOrCreateDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'device_uuid';
    String? uuid = prefs.getString(key);
    if (uuid != null) {
      return uuid;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (!kIsWeb) {
        if (Platform.isAndroid) {
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

    await prefs.setString(key, uuid);
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
