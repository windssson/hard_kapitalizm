import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastRegisteredToken;

  PushNotificationService(this._ref);

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isInitializing = true;

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
        _ref.invalidate(playerNotificationDashboardProvider);
        _ref.invalidate(homeDashboardProvider);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Firebase/FCM: $e');
    } finally {
      _isInitializing = false;
    }

    _startHeartbeat();
    _subscribeRealtime();
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
      debugPrint('Push token registered in Supabase: $token');
    } catch (e) {
      debugPrint('Error registering push token in Supabase: $e');
    }
  }

  Future<void> unregisterToken() async {
    final token = _lastRegisteredToken;
    try {
      await _supabase.rpc(
        'unregister_push_token',
        params: token != null ? {'p_token': token} : {},
      );
      _lastRegisteredToken = null;
      debugPrint('Push token unregistered from Supabase');
    } catch (e) {
      debugPrint('Error unregistering push token: $e');
    } finally {
      stopTracking();
      _isInitialized = false;
    }
  }

  void _subscribeRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase
        .channel('public:player_notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint('Realtime notification update received: ${payload.eventType}');
            _ref.invalidate(playerNotificationDashboardProvider);
            _ref.invalidate(homeDashboardProvider);
          },
        )
        .subscribe();
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
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(() {
    service.stopTracking();
  });
  return service;
});
