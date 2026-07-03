import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;

  PushNotificationService();


  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Initialize Firebase App
      await Firebase.initializeApp();

      // Request permissions (especially required for iOS and Android 13+)
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

      debugPrint('User granted notification permission: ${settings.authorizationStatus}');

      // Get FCM Token
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen to Token Refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _registerToken(newToken);
      });

      // Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received a foreground push message: ${message.notification?.title}');
      });

    } catch (e) {
      debugPrint('Error initializing Firebase/FCM: $e');
    }

    _startHeartbeat();
  }

  Future<void> _registerToken(String token) async {
    try {
      await _supabase.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_device_id': defaultTargetPlatform.name,
        },
      );
      debugPrint('Push token registered in Supabase: $token');
    } catch (e) {
      debugPrint('Error registering push token in Supabase: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      stopTracking();
      return;
    }

    try {
      await _supabase.rpc('update_player_heartbeat');
    } catch (e) {
      debugPrint('Error sending presence heartbeat: $e');
    }
  }

  void stopTracking() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService();
  ref.onDispose(() {
    service.stopTracking();
  });
  return service;
});
