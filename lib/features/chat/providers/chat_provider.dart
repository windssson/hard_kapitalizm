import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/chat/data/chat_service.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class ChatNotifier extends Notifier<ChatState> {
  RealtimeChannel? _channel;
  DateTime? _lastSentAt;

  @override
  ChatState build() => const ChatState();

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

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final oldest = state.messages.firstOrNull?.createdAt;
      if (oldest == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
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

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<bool> sendMessage({
    required String content,
    MarketListingModel? linkedListing,
  }) async {
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 3) {
      state = state.copyWith(error: '3 saniyede bir mesaj gonderilebilir.');
      return false;
    }
    if (content.trim().isEmpty && linkedListing == null) {
      return false;
    }

    state = state.copyWith(isSending: true, error: null);
    _lastSentAt = now;

    try {
      await ChatService.sendMessage(
        content: content,
        linkedListing: linkedListing,
      );
      state = state.copyWith(isSending: false);
      return true;
    } catch (e, st) {
      debugPrint(
        '[CHAT][PROVIDER][SEND][ERROR] type=${e.runtimeType} error=$e',
      );
      debugPrint('[CHAT][PROVIDER][SEND][STACK] $st');
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
