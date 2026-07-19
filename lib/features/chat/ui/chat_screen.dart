import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/chat/data/chat_service.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/chat/providers/chat_provider.dart';
import 'package:hard_kapitalizm/features/chat/providers/blocked_players_provider.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _scrolledToBottom = false;
  MarketListingModel? _selectedLinkedListing;

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
    if (text.isEmpty && _selectedLinkedListing == null) return;

    final sent = await ref
        .read(chatProvider.notifier)
        .sendMessage(content: text, linkedListing: _selectedLinkedListing);

    if (!sent) return;

    _controller.clear();
    if (mounted) {
      setState(() {
        _selectedLinkedListing = null;
      });
    }

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

  Future<void> _openLinkedProductPicker() async {
    final playerId = ref.read(playerProvider).value?.id;
    if (playerId == null) {
      AppSnackbar.show(
        context,
        title: 'Oyuncu Bulunamadi',
        message: 'Urun baglamak icin once oyuncu verisi yuklenmeli.',
        type: SnackbarType.warning,
      );
      return;
    }

    final selected = await showModalBottomSheet<MarketListingModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => _ChatProductPickerSheet(playerId: playerId),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedLinkedListing = selected;
    });
  }

  Future<void> _showMessageActions(ChatMessage msg, bool isMine) async {
    final action = await showModalBottomSheet<_ChatMessageAction>(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) =>
          _ChatMessageActionsSheet(message: msg, isMine: isMine),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _ChatMessageAction.openProfile:
        context.push('/profile/public/${msg.playerId}');
        return;
      case _ChatMessageAction.copyMessage:
        await Clipboard.setData(ClipboardData(text: msg.content));
        if (!mounted) return;
        AppSnackbar.show(
          context,
          title: 'Kopyalandi',
          message: 'Mesaj panoya kopyalandi.',
          type: SnackbarType.success,
        );
        return;
      case _ChatMessageAction.reportMessage:
        await _openReportSheet(msg);
        return;
      case _ChatMessageAction.blockPlayer:
        await _confirmBlockPlayer(msg.playerId, msg.playerName);
        return;
    }
  }

  Future<void> _confirmBlockPlayer(String playerId, String playerName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.red),
            SizedBox(width: 8.w),
            Text(
              'Oyuncuyu Engelle',
              style: AppTextStyles.title.standardCopyWith(color: AppColors.red),
            ),
          ],
        ),
        content: Text(
          '$playerName isimli oyuncuyu engellemek istediğinize emin misiniz?\n\nBu oyuncunun gönderdiği mesajları artık görmeyeceksiniz.',
          style: AppTextStyles.body.standardCopyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.label.standardCopyWith(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Engelle',
              style: AppTextStyles.label.standardCopyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(blockedPlayersProvider.notifier).blockPlayer(playerId);
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Oyuncu Engellendi',
          message: '$playerName başarıyla engellendi.',
          type: SnackbarType.success,
        );
      }
    }
  }

  Future<void> _openReportSheet(ChatMessage msg) async {
    final payload = await showModalBottomSheet<_ChatReportPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => _ChatReportSheet(message: msg),
    );

    if (!mounted || payload == null) return;

    try {
      final result = await ChatService.reportMessage(
        messageId: msg.id,
        reason: payload.reason,
        details: payload.details,
      );

      if (!mounted) return;

      final alreadyReported = result['already_reported'] == true;
      AppSnackbar.show(
        context,
        title: alreadyReported ? 'Bilgi' : 'Rapor Alindi',
        message: (result['message']?.toString().trim().isNotEmpty ?? false)
            ? result['message'].toString()
            : alreadyReported
            ? 'Bu mesaj zaten raporlanmis.'
            : 'Mesaj moderasyon ekibine gonderildi.',
        type: alreadyReported ? SnackbarType.warning : SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Rapor Hatasi',
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final currentPlayerId = ref.watch(playerProvider).value?.id;
    final blockedPlayers = ref.watch(blockedPlayersProvider);

    final visibleMessages = chatState.messages
        .where((m) => !blockedPlayers.contains(m.playerId))
        .toList();

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
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: (_) {},
      ),
      body: Column(
        children: [
          const SecondaryTopBar(title: 'Sohbet'),
          if (chatState.error != null) _buildErrorBanner(chatState.error!),
          Expanded(
            child: chatState.isLoading && visibleMessages.isEmpty
                ? Center(
                    child: AppLoadingIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  )
                : visibleMessages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    itemCount:
                        visibleMessages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chatState.isLoading && index == 0) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: AppLoadingIndicator(
                                color: AppColors.gold,
                                strokeWidth: 1.5,
                              ),
                            ),
                          ),
                        );
                      }

                      final msgIndex = chatState.isLoading ? index - 1 : index;
                      final msg = visibleMessages[msgIndex];
                      final isMine = msg.playerId == currentPlayerId;
                      return _buildMessageBubble(msg, isMine);
                    },
                  ),
          ),
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
            AppIcons.chatBubbleOutlineRounded,
            color: AppColors.gold.withValues(alpha: 0.3),
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 12.h),
          Text('Henuz mesaj yok', style: AppTextStyles.title),
          SizedBox(height: 6.h),
          Text('Ilk mesaji sen gonder!', style: AppTextStyles.body),
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
          Icon(
            AppIcons.warningAmberRounded,
            color: AppColors.red,
            size: AppIconSizes.small,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.red,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(chatProvider.notifier).clearError(),
            child: Icon(
              AppIcons.close,
              color: AppColors.red,
              size: AppIconSizes.small,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMine) {
    final h = msg.createdAt.hour.toString().padLeft(2, '0');
    final m = msg.createdAt.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showMessageActions(msg, isMine),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
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
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w, bottom: 3.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push('/profile/public/${msg.playerId}'),
                            child: Text(
                              msg.playerName,
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'Sv.${msg.playerLevel}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: AppTypography.micro,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    constraints: BoxConstraints(maxWidth: 280.w),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.linkedProduct != null)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: msg.content.isNotEmpty ? 8.h : 0,
                            ),
                            child: _ChatMessageLinkedProductCard(
                              linkedProduct: msg.linkedProduct!,
                              onTap: () => context.push(
                                '/profile/public/${msg.playerId}',
                              ),
                            ),
                          ),
                        if (msg.content.isNotEmpty)
                          Text(
                            msg.content,
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.body,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 3.h, left: 4.w, right: 4.w),
                    child: Text(
                      timeStr,
                      style: AppTextStyles.caption.standardCopyWith(
                        fontSize: AppTypography.micro,
                      ),
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
      ),
    );
  }

  Widget _buildAvatar(ChatMessage msg) {
    final isUrl =
        msg.avatarId.startsWith('http://') ||
        msg.avatarId.startsWith('https://');

    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBgLight,
        border: Border.all(color: AppColors.cardBorder, width: 1.w),
      ),
      child: ClipOval(
        child: isUrl
            ? Image.network(
                msg.avatarId,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  AppIcons.person,
                  color: AppColors.textMuted,
                  size: AppIconSizes.compact,
                ),
              )
            : Image.asset(
                'assets/avatars/${msg.avatarId}',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  AppIcons.person,
                  color: AppColors.textMuted,
                  size: AppIconSizes.compact,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedLinkedListing != null) ...[
              _ChatDraftLinkedProductCard(
                listing: _selectedLinkedListing!,
                onClear: () => setState(() => _selectedLinkedListing = null),
              ),
              SizedBox(height: 8.h),
            ],
            Row(
              children: [
                GestureDetector(
                  onTap: chatState.isSending ? null : _openLinkedProductPicker,
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 1.w,
                      ),
                    ),
                    child: Icon(
                      AppIcons.addRounded,
                      color: AppColors.gold,
                      size: AppIconSizes.regular,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    decoration: AppDecorations.card(),
                    child: TextField(
                      controller: _controller,
                      maxLength: 200,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedLinkedListing == null
                            ? 'Mesaj yaz...'
                            : 'Mesaja bir not ekle...',
                        hintStyle: AppTextStyles.body,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
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
                            child: AppLoadingIndicator(
                              color: AppColors.gold,
                              strokeWidth: 1.5,
                            ),
                          )
                        : Icon(
                            AppIcons.sendRounded,
                            color: AppColors.gold,
                            size: AppIconSizes.regular,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageLinkedProductCard extends StatelessWidget {
  const _ChatMessageLinkedProductCard({
    required this.linkedProduct,
    required this.onTap,
  });

  final ChatLinkedProduct linkedProduct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.28),
            width: 1.w,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: CachedAssetImage(
                fileName: linkedProduct.productIcon,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linkedProduct.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      _QualityStars(qualityLevel: linkedProduct.qualityLevel),
                      SizedBox(width: 6.w),
                      Text(
                        'Stok ${linkedProduct.quantity}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        AppMoney.compact(linkedProduct.price),
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.openInNewRounded,
              color: AppColors.gold,
              size: AppIconSizes.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatDraftLinkedProductCard extends StatelessWidget {
  const _ChatDraftLinkedProductCard({
    required this.listing,
    required this.onClear,
  });

  final MarketListingModel listing;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1.w,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: CachedAssetImage(
              fileName: listing.productIcon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    _QualityStars(qualityLevel: listing.qualityLevel),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'Stok ${listing.quantity} - ${AppMoney.compact(listing.price)}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.close,
                color: AppColors.red,
                size: AppIconSizes.small,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatProductPickerSheet extends ConsumerWidget {
  const _ChatProductPickerSheet({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(playerMarketListingsProvider(playerId));

    return Container(
      decoration: AppDecorations.bottomSheet(),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Satisa Acik Urun Sec',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Mesajina bir urun ilani ekleyebilirsin.',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: listingsAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, _) => Center(
                  child: Text(
                    'Urunler yuklenemedi: $error',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (listings) {
                  final saleListings = listings
                      .where(
                        (item) => item.isAvailableForSale && item.quantity > 0,
                      )
                      .toList();

                  if (saleListings.isEmpty) {
                    return Center(
                      child: Text(
                        'Su anda satisa acik urunun yok.',
                        style: AppTextStyles.body,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: saleListings.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final listing = saleListings[index];
                      return InkWell(
                        onTap: () => Navigator.pop(context, listing),
                        borderRadius: BorderRadius.circular(14.r),
                        child: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppColors.cardBgLight,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.cardBorder,
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                padding: EdgeInsets.all(5.w),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withValues(
                                    alpha: 0.24,
                                  ),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: CachedAssetImage(
                                  fileName: listing.productIcon,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.body
                                          .standardCopyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    SizedBox(height: 3.h),
                                    Row(
                                      children: [
                                        _QualityStars(
                                          qualityLevel: listing.qualityLevel,
                                        ),
                                        SizedBox(width: 6.w),
                                        Expanded(
                                          child: Text(
                                            'Stok ${listing.quantity}',
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '${listing.warehouseName} / ${listing.cityName}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppMoney.compact(listing.price),
                                    style: AppTextStyles.body.standardCopyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Icon(
                                    AppIcons.chevronRightRounded,
                                    color: AppColors.textMuted,
                                    size: AppIconSizes.small,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityStars extends StatelessWidget {
  const _QualityStars({required this.qualityLevel});

  final int qualityLevel;

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = qualityLevel.clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < normalizedLevel;
        return Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : 1.w),
          child: Icon(
            filled ? AppIcons.starRounded : AppIcons.starBorderRounded,
            color: filled ? AppColors.gold : AppColors.textMuted,
            size: AppIconSizes.compact,
          ),
        );
      }),
    );
  }
}

enum _ChatMessageAction { openProfile, copyMessage, reportMessage, blockPlayer }

class _ChatMessageActionsSheet extends StatelessWidget {
  const _ChatMessageActionsSheet({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.bottomSheet(),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              message.playerName,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              message.content.isEmpty ? 'Bagli urun mesaji' : message.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            _ChatActionTile(
              icon: AppIcons.openInNewRounded,
              label: 'Profili Ac',
              onTap: () =>
                  Navigator.pop(context, _ChatMessageAction.openProfile),
            ),
            _ChatActionTile(
              icon: Icons.content_copy_rounded,
              label: 'Mesaji Kopyala',
              onTap: () =>
                  Navigator.pop(context, _ChatMessageAction.copyMessage),
            ),
            if (!isMine) ...[
              _ChatActionTile(
                icon: AppIcons.flagOutlined,
                label: 'Mesaji Raporla',
                color: AppColors.red,
                onTap: () =>
                    Navigator.pop(context, _ChatMessageAction.reportMessage),
              ),
              _ChatActionTile(
                icon: Icons.block_rounded,
                label: 'Oyuncuyu Engelle',
                color: AppColors.red,
                onTap: () =>
                    Navigator.pop(context, _ChatMessageAction.blockPlayer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatActionTile extends StatelessWidget {
  const _ChatActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: resolvedColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: resolvedColor,
                size: AppIconSizes.regular,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.standardCopyWith(
                  color: resolvedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              AppIcons.chevronRightRounded,
              color: AppColors.textMuted,
              size: AppIconSizes.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatReportSheet extends StatefulWidget {
  const _ChatReportSheet({required this.message});

  final ChatMessage message;

  @override
  State<_ChatReportSheet> createState() => _ChatReportSheetState();
}

class _ChatReportSheetState extends State<_ChatReportSheet> {
  final _detailsController = TextEditingController();
  String _selectedReason = _chatReportReasons.first.key;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.bottomSheet(),
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Mesaj Raporla',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.message.content.isEmpty
                  ? 'Bagli urun mesaji'
                  : widget.message.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
            ),
            SizedBox(height: 16.h),
            Text(
              'Sebep',
              style: AppTextStyles.label.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _chatReportReasons.map((reason) {
                final selected = reason.key == _selectedReason;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = reason.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.gold.withValues(alpha: 0.18)
                          : AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(
                        color: selected
                            ? AppColors.gold.withValues(alpha: 0.6)
                            : AppColors.cardBorder,
                        width: 1.w,
                      ),
                    ),
                    child: Text(
                      reason.label,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: selected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16.h),
            Text(
              'Ek Not',
              style: AppTextStyles.label.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 4,
              maxLength: 240,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Istersen kisa bir aciklama ekle...',
                counterText: '',
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgec'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    style: AppButtonStyles.primary(
                      backgroundColor: AppColors.red,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _ChatReportPayload(
                          reason: _selectedReason,
                          details: _detailsController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Raporla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatReportPayload {
  const _ChatReportPayload({required this.reason, required this.details});

  final String reason;
  final String details;
}

class _ChatReportReasonOption {
  const _ChatReportReasonOption({required this.key, required this.label});

  final String key;
  final String label;
}

const List<_ChatReportReasonOption> _chatReportReasons = [
  _ChatReportReasonOption(key: 'spam', label: 'Spam'),
  _ChatReportReasonOption(key: 'hakaret', label: 'Hakaret'),
  _ChatReportReasonOption(key: 'uygunsuz_icerik', label: 'Uygunsuz Icerik'),
  _ChatReportReasonOption(key: 'aldatma', label: 'Aldatma'),
  _ChatReportReasonOption(key: 'diger', label: 'Diger'),
];
