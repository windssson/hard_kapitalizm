import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/chat/providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _scrolledToBottom = false;

  late final ChatNotifier _chatNotifier;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(chatProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chatNotifier.loadInitial();
      _chatNotifier.subscribeRealtime();
      _scrollToBottom();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _chatNotifier.unsubscribeRealtime();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // En üste yaklaştıysa eski mesajları yükle
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 80) {
      ref.read(chatProvider.notifier).loadMore();
    }
  }

  void _scrollToBottom() {
    if (!_scrolledToBottom && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _scrolledToBottom = true;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final player = ref.read(playerProvider).value;
    if (player == null) return;

    _controller.clear();

    await ref.read(chatProvider.notifier).sendMessage(
          playerId: player.id,
          playerName: player.playerName,
          avatarId: player.avatarId,
          playerLevel: player.level,
          content: text,
        );

    // Gönderim sonrası en alta kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final currentPlayerId = ref.watch(playerProvider).value?.id;

    // Yeni mesaj gelince en alta kaydır
    ref.listen(chatProvider, (prev, next) {
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last.playerId == currentPlayerId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: (_) {},
      ),
      body: Column(
        children: [
          const SecondaryTopBar(title: 'Global Sohbet 🌐'),
          // Hata mesajı
          if (chatState.error != null)
            _buildErrorBanner(chatState.error!),
          // Mesaj listesi
          Expanded(
            child: chatState.isLoading && chatState.messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  )
                : chatState.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 12.h),
                        itemCount: chatState.messages.length +
                            (chatState.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // En üstte yükleme göstergesi
                          if (chatState.isLoading && index == 0) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: AppColors.gold,
                                    strokeWidth: 1.5,
                                  ),
                                ),
                              ),
                            );
                          }
                          final msgIndex =
                              chatState.isLoading ? index - 1 : index;
                          final msg = chatState.messages[msgIndex];
                          final isMine = msg.playerId == currentPlayerId;
                          return _buildMessageBubble(msg, isMine);
                        },
                      ),
          ),
          // Mesaj giriş alanı
          _buildInputBar(chatState),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.gold.withValues(alpha: 0.3),
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text('Henüz mesaj yok', style: AppTextStyles.title),
          SizedBox(height: 6.h),
          Text(
            'İlk mesajı sen gönder!',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: AppColors.red.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 14.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.caption.copyWith(color: AppColors.red),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(chatProvider.notifier).clearError(),
            child: Icon(Icons.close, color: AppColors.red, size: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMine) {
    final h = msg.createdAt.hour.toString().padLeft(2, '0');
    final m = msg.createdAt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: () => context.push('/profile/public/${msg.playerId}'),
              child: _buildAvatar(msg),
            ),
            SizedBox(width: 6.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 3.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/profile/public/${msg.playerId}'),
                          child: Text(
                            msg.playerName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Sv.${msg.playerLevel}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.gold,
                              fontSize: 7.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 8.h),
                  constraints: BoxConstraints(maxWidth: 260.w),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.cardBgLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14.r),
                      topRight: Radius.circular(14.r),
                      bottomLeft: Radius.circular(isMine ? 14.r : 2.r),
                      bottomRight: Radius.circular(isMine ? 2.r : 14.r),
                    ),
                    border: Border.all(
                      color: isMine
                          ? AppColors.gold.withValues(alpha: 0.35)
                          : AppColors.cardBorder,
                      width: 1.w,
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: AppTextStyles.body.copyWith(
                      color: isMine
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 3.h, left: 4.w, right: 4.w),
                  child: Text(
                    timeStr,
                    style: AppTextStyles.caption.copyWith(fontSize: 8.sp),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            SizedBox(width: 6.w),
            GestureDetector(
              onTap: () => context.push('/profile/public/${msg.playerId}'),
              child: _buildAvatar(msg),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage msg) {
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBgLight,
        border: Border.all(color: AppColors.cardBorder, width: 1.w),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/avatars/${msg.avatarId}',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.person,
            color: AppColors.textMuted,
            size: 16.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(ChatState chatState) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.h),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: AppDecorations.card(),
                child: TextField(
                  controller: _controller,
                  maxLength: 200,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: AppTextStyles.body,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: chatState.isSending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: chatState.isSending
                      ? AppColors.cardBgLight
                      : AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: chatState.isSending
                        ? AppColors.cardBorder
                        : AppColors.gold.withValues(alpha: 0.5),
                    width: 1.w,
                  ),
                ),
                child: chatState.isSending
                    ? Padding(
                        padding: EdgeInsets.all(10.w),
                        child: const CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 1.5,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: AppColors.gold,
                        size: 18.sp,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
