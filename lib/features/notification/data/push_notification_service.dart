import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastRegisteredToken;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  /// Bildirime tıklandığında rota yönlendirmesi yapacak global callback
  static void Function(RemoteMessage message)? onNotificationOpened;

  PushNotificationService([Ref? _]);

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isInitializing = true;

    try {
      // 1. Firebase App başlat
      await Firebase.initializeApp();

      // 2. Bildirim izinlerini iste (iOS ve Android 13+)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Bildirim izni durumu: ${settings.authorizationStatus}');

      // 3. Ön plandayken de sistem bildiriminin gösterilmesine izin ver
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Eski abonelikleri iptal et (sızıntı önleme)
      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Ön planda FCM bildirimi alındı: ${message.notification?.title}');
      });

      // Bildirime tıklandığında yönlendirme kancası (Arka plandan açılma)
      _onMessageOpenedAppSub?.cancel();
      _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Bildirime tıklanarak uygulama açıldı: ${message.data}');
        onNotificationOpened?.call(message);
      });

      // Uygulama tamamen kapalıyken bildirime tıklanarak açıldıysa
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Kapalıyken bildirime tıklanarak başlatıldı: ${initialMessage.data}');
        onNotificationOpened?.call(initialMessage);
      }

      // 4. Cihaz FCM Token'ını al ve Supabase'e kaydet
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // 5. Token yenilendiğinde otomatik olarak güncelle
      _onTokenRefreshSub?.cancel();
      _onTokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _registerToken(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('FCM Başlatma Hatası: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    if (_lastRegisteredToken == token) return;
    try {
      await _supabase.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_device_id': defaultTargetPlatform.name,
        },
      );
      _lastRegisteredToken = token;
      debugPrint('FCM Token Supabase veritabanına kaydedildi: $token');
    } catch (e) {
      debugPrint('FCM Token Supabase kayıt hatası: $e');
    }
  }

  Future<void> unregisterToken() async {
    stopTracking();
    final token = _lastRegisteredToken;
    try {
      await _supabase.rpc(
        'unregister_push_token',
        params: token != null ? {'p_token': token} : {},
      );
      _lastRegisteredToken = null;
      debugPrint('FCM Token kaydı Supabase üzerinden silindi');
    } catch (e) {
      debugPrint('FCM Token silme hatası: $e');
    } finally {
      _isInitialized = false;
    }
  }

  void stopTracking() {
    _onMessageSub?.cancel();
    _onMessageSub = null;
    _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = null;
    _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = null;
    _isInitialized = false;
    debugPrint('PushNotificationService dinleyicileri temizlendi.');
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(() {
    service.stopTracking();
  });
  return service;
});
