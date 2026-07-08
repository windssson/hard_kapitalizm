import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/chat/data/chat_service.dart';

// ─────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Notifier (Riverpod 3.x)
// ─────────────────────────────────────────────────────────────────
class ChatNotifier extends Notifier<ChatState> {
  RealtimeChannel? _channel;
  DateTime? _lastSentAt;

  @override
  ChatState build() => const ChatState();

  /// İlk yükleme
  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final msgs = await ChatService.fetchLatest();
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        hasMore: msgs.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Yukarı kaydırınca eski mesajları yükle
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final oldest = state.messages.first.createdAt;
      final older = await ChatService.fetchBefore(oldest);
      state = state.copyWith(
        messages: [...older, ...state.messages],
        isLoading: false,
        hasMore: older.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Realtime subscription başlat
  void subscribeRealtime() {
    _channel = ChatService.subscribeToNewMessages(
      onInsert: (msg) {
        final alreadyExists = state.messages.any((m) => m.id == msg.id);
        if (!alreadyExists) {
          state = state.copyWith(messages: [...state.messages, msg]);
        }
      },
    );
  }

  /// Realtime subscription durdur
  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Mesaj gönder (3 sn spam koruması)
  Future<void> sendMessage({
    required String playerId,
    required String playerName,
    required String avatarId,
    required int playerLevel,
    required String content,
  }) async {
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 3) {
      state = state.copyWith(error: '3 saniyede bir mesaj gönderilebilir.');
      return;
    }
    if (content.trim().isEmpty) return;

    state = state.copyWith(isSending: true, error: null);
    _lastSentAt = now;

    try {
      await ChatService.sendMessage(
        playerId: playerId,
        playerName: playerName,
        avatarId: avatarId,
        playerLevel: playerLevel,
        content: content,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ─────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────
final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
