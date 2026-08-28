import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/chat/data/chat_service.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatState {
  final List<ChatMessage> messages;
  final String activeChannel; // 'global', 'trade', 'city'
  final int? cityId;
  final ChatMessage? replyingTo;
  final bool isLoading;
  final bool hasMore;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.activeChannel = 'global',
    this.cityId,
    this.replyingTo,
    this.isLoading = false,
    this.hasMore = true,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? activeChannel,
    int? cityId,
    ChatMessage? replyingTo,
    bool clearReply = false,
    bool? isLoading,
    bool? hasMore,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      activeChannel: activeChannel ?? this.activeChannel,
      cityId: cityId ?? this.cityId,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
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

  Future<void> loadInitial({String? channel, int? cityId}) async {
    final ch = channel ?? state.activeChannel;
    final cId = cityId ?? state.cityId;

    state = state.copyWith(
      isLoading: true,
      error: null,
      activeChannel: ch,
      cityId: cId,
    );

    try {
      final msgs = await ChatService.fetchLatest(
        channel: ch,
        cityId: cId,
      );
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        hasMore: msgs.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> switchChannel(String channel, {int? cityId}) async {
    if (state.activeChannel == channel && state.cityId == cityId) return;
    await loadInitial(channel: channel, cityId: cityId);
  }

  void setReply(ChatMessage? message) {
    state = state.copyWith(replyingTo: message);
  }

  void clearReply() {
    state = state.copyWith(clearReply: true);
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
      final older = await ChatService.fetchBefore(
        oldest,
        channel: state.activeChannel,
        cityId: state.cityId,
      );
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
    _channel?.unsubscribe();
    _channel = ChatService.subscribeToNewMessages(
      onInsert: (msg) {
        if (msg.channel != state.activeChannel) return;
        if (msg.channel == 'city' && state.cityId != null) {
          // If city channel, check city match
        }

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
      state = state.copyWith(error: 'Lütfen mesajlar arasında 3 saniye bekleyin.');
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
        channel: state.activeChannel,
        linkedListing: linkedListing,
        replyToMessageId: state.replyingTo?.id,
      );
      state = state.copyWith(isSending: false, clearReply: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
