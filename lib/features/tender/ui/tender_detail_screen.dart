import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';

class TenderDetailScreen extends ConsumerStatefulWidget {
  const TenderDetailScreen({
    super.key,
    this.tenderId,
    this.playerTenderId,
  }) : assert(
         (tenderId != null && playerTenderId == null) ||
             (tenderId == null && playerTenderId != null),
         'Either tenderId or playerTenderId must be provided.',
       );

  final String? tenderId;
  final String? playerTenderId;

  @override
  ConsumerState<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends ConsumerState<TenderDetailScreen> {
  bool _isSubmitting = false;

  bool get _isPlayerTender => widget.playerTenderId != null;

  Future<void> _refresh() async {
    await ref.read(tenderActionProvider).refreshTenderRuntime();
    if (_isPlayerTender) {
      await ref.read(playerTenderDetailProvider(widget.playerTenderId!).notifier).refresh();
      return;
    }
    await ref.read(tenderDetailProvider(widget.tenderId!).notifier).refresh();
  }

  Future<void> _acceptTender(TenderDetailModel detail) async {
    if (widget.tenderId == null || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'İhaleyi Al',
          style: AppTextStyles.title.standardCopyWith(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${detail.tender.title} ihalesini almak üzeresiniz.',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
            ),
            SizedBox(height: 8.h),
            Text(
              'Bağlanacak Teminat: ₺${AppMoney.compact(detail.tender.bondAmount)}',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.red,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Teslimat Süresi: ${detail.tender.deliveryDurationMinutes} Dakika',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.blue,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('Onayla ve Al'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .acceptTender(widget.tenderId!);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Tebrikler!',
        message: (result['message'] ?? 'İhale başarıyla alındı.').toString(),
        type: SnackbarType.success,
      );
      final playerTenderId = (result['player_tender_id'] ?? '').toString();
      if (playerTenderId.isNotEmpty) {
        context.go('/tenders/player/$playerTenderId');
      } else {
        await _refresh();
      }
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'İhale kabul edilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  Future<void> _cancelTender(TenderDetailModel detail) async {
    final playerTender = detail.playerTender;
    if (playerTender == null || _isSubmitting) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'İhaleyi İptal Et',
            style: AppTextStyles.title.standardCopyWith(color: AppColors.red),
          ),
          content: Text(
            'İhaleyi iptal ederseniz yatırdığınız teminat tutarı (₺${AppMoney.compact(detail.tender.bondAmount)}) yanacaktır.\n\nİptal etmek istediğinize emin misiniz?',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Evet, İptal Et'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .cancelPlayerTender(playerTender.id);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'İhale İptal Edildi',
        message: (result['message'] ?? 'İhale iptal edildi.').toString(),
        type: SnackbarType.warning,
      );
      await _refresh();
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'İhale iptal edilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  void _openBidModal(TenderDetailModel detail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => _BidModalContent(
        detail: detail,
        tenderId: widget.tenderId!,
        onSuccess: () {
          Navigator.pop(ctx);
          _refresh();
        },
      ),
    );
  }

  void _openDeliveryModal(TenderDetailModel detail) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => _DeliveryModalContent(
        detail: detail,
        onSuccess: () {
          Navigator.pop(ctx);
          _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = _isPlayerTender
        ? ref.watch(playerTenderDetailProvider(widget.playerTenderId!))
        : ref.watch(tenderDetailProvider(widget.tenderId!));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(
              title: _isPlayerTender ? 'Aktif İhale Detayı' : 'İhale Şartnamesi',
            ),
            Expanded(
              child: detailAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.body,
                      ),
                    ),
                  ),
                ),
                data: (detail) {
                  final playerTender = detail.playerTender;
                  final hasPlayerTender = playerTender != null;
                  final isActiveTender = playerTender?.status == 'active';
                  final totalStockInWarehouses = detail.warehouseOptions.fold<int>(
                    0,
                    (sum, item) => sum + item.availableQuantity,
                  );

                  return Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
                            children: [
                              // 1. Ana İhale Bilgi Kartı
                              _TenderHeroCard(
                                detail: detail,
                                isOpenTenderView: !_isPlayerTender,
                              ),
                              SizedBox(height: 12.h),

                              // 2. Oyuncunun İhalesi İse: İlerleme & Durum
                              if (hasPlayerTender) ...[
                                _PlayerTenderProgressCard(
                                  playerTender: playerTender,
                                  detail: detail,
                                ),
                                SizedBox(height: 12.h),
                              ],

                              // 3. Yoldaki Aktif Sevkiyatlar
                              if (detail.activeDeliveries.isNotEmpty) ...[
                                _ActiveDeliveriesCard(
                                  deliveries: detail.activeDeliveries,
                                ),
                                SizedBox(height: 12.h),
                              ],

                              // 4. Depolardaki Stok Durumu Özeti
                              _StockSummaryCard(
                                totalStock: totalStockInWarehouses,
                                requiredQuantity: hasPlayerTender
                                    ? playerTender.remainingQuantity
                                    : detail.tender.requiredQuantity,
                                isPlayerTender: hasPlayerTender,
                              ),
                              SizedBox(height: 12.h),

                              // 5. İhale Şartları & Açıklama
                              _TenderTermsCard(detail: detail),
                            ],
                          ),
                        ),
                      ),

                      // 6. Sayfa Altı Sabit Aksiyon Çubuğu (Bottom Action Bar)
                      _buildBottomActionBar(detail, hasPlayerTender, isActiveTender),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    TenderDetailModel detail,
    bool hasPlayerTender,
    bool isActiveTender,
  ) {
    if (_isPlayerTender) {
      if (!hasPlayerTender || !isActiveTender) {
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border(top: BorderSide(color: AppColors.borderGoldLight.withValues(alpha: 0.15))),
          ),
          child: Text(
            hasPlayerTender
                ? 'Bu ihale tamamlandı veya süresi sona erdi.'
                : 'İhale kaydı bulunamadı.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.standardCopyWith(color: AppColors.textMuted),
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _openDeliveryModal(detail),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: const Icon(AppIcons.localShippingRounded),
                label: Text(
                  'Sevkiyat Yap',
                  style: AppTextStyles.button.standardCopyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTypography.body,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => _cancelTender(detail),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.red.withValues(alpha: 0.7)),
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'İptal',
                  style: AppTextStyles.button.standardCopyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Açık İhale Görünümü
    final isFirstClaim = detail.tender.awardType == 'first_claim';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => isFirstClaim ? _acceptTender(detail) : _openBidModal(detail),
          style: FilledButton.styleFrom(
            backgroundColor: isFirstClaim ? AppColors.gold : AppColors.green,
            foregroundColor: AppColors.textOnAccent,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: Icon(isFirstClaim ? Icons.assignment_turned_in_rounded : AppIcons.gavelRounded),
          label: Text(
            isFirstClaim
                ? 'İhaleyi Hemen Al'
                : (detail.playerBid != null ? 'Teklifi Düzenle' : 'Teklif Ver'),
            style: AppTextStyles.button.standardCopyWith(
              fontWeight: FontWeight.w800,
              fontSize: AppTypography.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 1. Ana İhale Bilgi Kartı ──────────────────────────────────────────────────
class _TenderHeroCard extends StatelessWidget {
  const _TenderHeroCard({
    required this.detail,
    required this.isOpenTenderView,
  });

  final TenderDetailModel detail;
  final bool isOpenTenderView;

  @override
  Widget build(BuildContext context) {
    final tender = detail.tender;
    final totalReward = tender.rewardCash;
    final unitReward = tender.requiredQuantity > 0 ? (totalReward / tender.requiredQuantity) : 0.0;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.glowingAction(AppColors.gold, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68.w,
                height: 68.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppFx.softOverlay(0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.24),
                  ),
                ),
                child: CachedAssetImage(
                  fileName: tender.productIcon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tender.title,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.titleLarge,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${tender.cityName} • ${tender.productName}',
                      style: AppTextStyles.body.standardCopyWith(
                        fontSize: AppTypography.bodySmall,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _HeroPill(
                          text: tender.awardType == 'first_claim'
                              ? 'İlk Alan Kazanır'
                              : 'Teklif Usulü',
                          color: tender.awardType == 'first_claim'
                              ? AppColors.goldLight
                              : AppColors.green,
                        ),
                        _HeroPill(
                          text: '${tender.requiredQuantity} adet',
                          color: AppColors.gold,
                        ),
                        _HeroPill(
                          text: 'Kalite ${tender.qualityLevel}',
                          color: AppColors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: AppFx.softOverlay(0.12), height: 1),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: isOpenTenderView ? 'Toplam Bütçe' : 'Kazanılan Ödül',
                  value: '₺${AppMoney.compact(totalReward)}',
                  subtitle: '₺${unitReward.toStringAsFixed(1)} / adet',
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Bağlanan Teminat',
                  value: '₺${AppMoney.compact(tender.bondAmount)}',
                  color: AppColors.red,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Teslimat Süresi',
                  value: '${tender.deliveryDurationMinutes} Dk',
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 2. Oyuncu İlerleme Kartı ──────────────────────────────────────────────────
class _PlayerTenderProgressCard extends ConsumerWidget {
  const _PlayerTenderProgressCard({
    required this.playerTender,
    required this.detail,
  });

  final PlayerTenderDetailSummaryModel playerTender;
  final TenderDetailModel detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final requiredQuantity = playerTender.requiredQuantity;
    final delivered = playerTender.deliveredQuantity;
    final inTransit = playerTender.inTransitQuantity;
    final remaining = playerTender.remainingQuantity;
    final progress = requiredQuantity > 0 ? (delivered / requiredQuantity).clamp(0.0, 1.0) : 0.0;

    final isExpired = playerTender.deadlineAt != null && playerTender.deadlineAt!.isBefore(now);
    final remainingDuration = playerTender.deadlineAt == null || isExpired
        ? Duration.zero
        : playerTender.deadlineAt!.difference(now);

    final hours = remainingDuration.inHours;
    final minutes = remainingDuration.inMinutes % 60;
    final seconds = remainingDuration.inSeconds % 60;
    final timeStr = isExpired
        ? 'Süre Doldu'
        : '${hours > 0 ? '$hours sa ' : ''}$minutes dk $seconds sn';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(AppColors.blue, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teslimat İlerlemesi',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isExpired ? AppColors.red : AppColors.blue).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: (isExpired ? AppColors.red : AppColors.blue).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14.sp,
                      color: isExpired ? AppColors.red : AppColors.gold,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      timeStr,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: isExpired ? AppColors.red : AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: AppProgressBar(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppFx.softOverlay(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: 'Teslim Edilen',
                  value: '$delivered adet',
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Yoldaki',
                  value: '$inTransit adet',
                  color: AppColors.blue,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Kalan İhtiyaç',
                  value: '$remaining adet',
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 3. Stok Durumu Özeti ──────────────────────────────────────────────────────
class _StockSummaryCard extends StatelessWidget {
  const _StockSummaryCard({
    required this.totalStock,
    required this.requiredQuantity,
    required this.isPlayerTender,
  });

  final int totalStock;
  final int requiredQuantity;
  final bool isPlayerTender;

  @override
  Widget build(BuildContext context) {
    final hasEnough = totalStock >= requiredQuantity;
    final diff = (requiredQuantity - totalStock).abs();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasEnough ? AppIcons.checkCircleRounded : AppIcons.warningAmberRounded,
            size: AppIconSizes.medium,
            color: hasEnough ? AppColors.green : AppColors.warning,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Depolardaki Toplam Stok: $totalStock adet',
                  style: AppTextStyles.label.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  hasEnough
                      ? 'Tüm teslimatı karşılayacak hazır stoğunuz bulunuyor.'
                      : 'Eksik: $diff adet daha üretmeli veya pazardan almalısınız.',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: hasEnough ? AppColors.green : AppColors.warning,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. İhale Şartları & Açıklama ──────────────────────────────────────────────
class _TenderTermsCard extends StatelessWidget {
  const _TenderTermsCard({required this.detail});

  final TenderDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final tender = detail.tender;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İhale Şartnamesi',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          if (tender.description.trim().isNotEmpty) ...[
            Text(
              tender.description,
              style: AppTextStyles.body.standardCopyWith(
                fontSize: AppTypography.bodySmall,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10.h),
          ],
          _TermRow(
            icon: Icons.location_on_outlined,
            title: 'Teslim Şehri',
            value: tender.cityName,
          ),
          _TermRow(
            icon: Icons.grade_outlined,
            title: 'Asgari Kalite',
            value: 'Kalite ${tender.qualityLevel}',
          ),
          _TermRow(
            icon: Icons.inventory_2_outlined,
            title: 'Birim Hacim',
            value: '${tender.productUnitVolume.toStringAsFixed(2)} m³',
          ),
          _TermRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Teminat Kuralı',
            value: 'Başarıyla tamamlandığında teminat %100 iade edilir.',
          ),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.goldLight),
          SizedBox(width: 8.w),
          Text(
            '$title: ',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5. Sevkiyat Hazırlığı Modal Penceresi (Modal Bottom Sheet) ─────────────────
class _DeliveryModalContent extends ConsumerStatefulWidget {
  const _DeliveryModalContent({
    required this.detail,
    required this.onSuccess,
  });

  final TenderDetailModel detail;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_DeliveryModalContent> createState() => _DeliveryModalContentState();
}

class _DeliveryModalContentState extends ConsumerState<_DeliveryModalContent> {
  String? _selectedWarehouseId;
  String? _selectedVehicleId;
  int _selectedQuantity = 0;
  bool _isSubmitting = false;

  TenderWarehouseOptionModel? _getWarehouse() {
    if (widget.detail.warehouseOptions.isEmpty) return null;
    if (_selectedWarehouseId != null) {
      for (final item in widget.detail.warehouseOptions) {
        if (item.warehouseId == _selectedWarehouseId) return item;
      }
    }
    return widget.detail.warehouseOptions.first;
  }

  @override
  void initState() {
    super.initState();
    final wh = _getWarehouse();
    if (wh != null) {
      _selectedWarehouseId = wh.warehouseId;
      final remaining = widget.detail.playerTender?.remainingQuantity ?? 0;
      _selectedQuantity = wh.availableQuantity < remaining ? wh.availableQuantity : remaining;
    }
  }

  Future<void> _submit() async {
    final playerTender = widget.detail.playerTender;
    final warehouse = _getWarehouse();
    if (playerTender == null || warehouse == null || _selectedQuantity <= 0 || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .startTenderDelivery(
          playerTenderId: playerTender.id,
          warehouseId: warehouse.warehouseId,
          vehicleId: warehouse.sameCity ? null : _selectedVehicleId,
          quantity: _selectedQuantity,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Sevkiyat Başlatıldı',
        message: (result['message'] ?? 'Teslimat başarıyla yola çıktı.').toString(),
        type: SnackbarType.success,
      );
      widget.onSuccess();
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Teslimat başlatılamadı.').toString(),
      type: SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = _getWarehouse();
    final remainingRequired = widget.detail.playerTender?.remainingQuantity ?? 0;
    final maxDeliverable = warehouse == null
        ? 0
        : (warehouse.availableQuantity < remainingRequired
            ? warehouse.availableQuantity
            : remainingRequired);

    final unitVolume = widget.detail.tender.productUnitVolume > 0
        ? widget.detail.tender.productUnitVolume
        : 1.0;
    final totalVolume = _selectedQuantity * unitVolume;

    final vehicleOptionsRequest = warehouse == null || warehouse.sameCity || _selectedQuantity <= 0
        ? null
        : TenderVehicleOptionsRequest(
            sourceCityId: warehouse.cityId,
            targetCityId: widget.detail.tender.cityId,
            totalVolume: totalVolume,
          );

    final vehicleOptionsAsync = vehicleOptionsRequest == null
        ? null
        : ref.watch(tenderVehicleOptionsProvider(vehicleOptionsRequest));

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sevkiyat Hazırlığı',
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: ListView(
              children: [
                // 1. Depo Seçimi
                _WarehouseSelectionCard(
                  detail: widget.detail,
                  selectedWarehouseId: _selectedWarehouseId,
                  onSelected: (whId) {
                    setState(() {
                      _selectedWarehouseId = whId;
                      _selectedVehicleId = null;
                      final newWh = _getWarehouse();
                      if (newWh != null) {
                        final maxQ = newWh.availableQuantity < remainingRequired
                            ? newWh.availableQuantity
                            : remainingRequired;
                        if (_selectedQuantity > maxQ) _selectedQuantity = maxQ;
                      }
                    });
                  },
                ),
                SizedBox(height: 12.h),

                // 2. Miktar Belirleme
                if (warehouse != null) ...[
                  _QuantityCard(
                    quantity: _selectedQuantity,
                    maxQuantity: maxDeliverable,
                    onChanged: (val) {
                      setState(() {
                        _selectedQuantity = val;
                        _selectedVehicleId = null;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),

                  // 3. Şehirlerarası ise Araç Seçimi
                  if (!warehouse.sameCity) ...[
                    _VehicleSelectionCard(
                      optionsAsync: vehicleOptionsAsync,
                      selectedVehicleId: _selectedVehicleId,
                      onSelected: (vehId) {
                        setState(() => _selectedVehicleId = vehId);
                      },
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // 4. Kâr & Masraf Hesaplayıcı
                  if (_selectedQuantity > 0) ...[
                    Builder(
                      builder: (ctx) {
                        double transportCost = 0.0;
                        if (!warehouse.sameCity &&
                            _selectedVehicleId != null &&
                            vehicleOptionsAsync != null) {
                          vehicleOptionsAsync.whenData((result) {
                            for (final opt in result.options) {
                              if (opt.vehicleId == _selectedVehicleId) {
                                transportCost = opt.transportCost;
                              }
                            }
                          });
                        }
                        final totalReward = widget.detail.tender.rewardCash;
                        final totalReq = widget.detail.playerTender?.requiredQuantity ??
                            widget.detail.tender.requiredQuantity;
                        final unitReward = totalReq > 0 ? (totalReward / totalReq) : 0.0;
                        final double realUnitCost = warehouse.unitCost > 0
                            ? warehouse.unitCost
                            : (widget.detail.tender.productBasePrice > 0
                                ? widget.detail.tender.productBasePrice
                                : 0.0);
                        final bool isCostEstimated = realUnitCost <= 0;

                        return _DeliveryProfitCalculator(
                          quantity: _selectedQuantity,
                          unitRewardCash: unitReward,
                          unitCost: isCostEstimated ? (unitReward * 0.60) : realUnitCost,
                          isCostEstimated: isCostEstimated,
                          sameCity: warehouse.sameCity,
                          transportCost: transportCost,
                        );
                      },
                    ),
                    SizedBox(height: 14.h),
                  ],
                ],
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ||
                      _selectedQuantity <= 0 ||
                      warehouse == null ||
                      warehouse.availableQuantity <= 0 ||
                      (!warehouse.sameCity &&
                          (_selectedVehicleId == null || _selectedVehicleId!.isEmpty))
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.textOnAccent,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              icon: _isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: Center(child: AppLoadingIndicator(strokeWidth: 2, color: AppColors.textOnAccent)),
                    )
                  : const Icon(AppIcons.localShippingRounded),
              label: Text(
                'Teslimatı Yola Çıkar',
                style: AppTextStyles.button.standardCopyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 6. Teklif Verme Modal Penceresi ───────────────────────────────────────────
class _BidModalContent extends ConsumerStatefulWidget {
  const _BidModalContent({
    required this.detail,
    required this.tenderId,
    required this.onSuccess,
  });

  final TenderDetailModel detail;
  final String tenderId;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_BidModalContent> createState() => _BidModalContentState();
}

class _BidModalContentState extends ConsumerState<_BidModalContent> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final desiredValue = ((widget.detail.playerBid?.bidAmount ?? widget.detail.tender.rewardCash)
            .round())
        .toString();
    _controller.text = desiredValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    final bidAmount = double.tryParse(raw) ?? 0;
    if (bidAmount <= 0 || _isSubmitting) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Geçerli bir teklif tutarı giriniz.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .submitTenderBid(
          tenderId: widget.tenderId,
          bidAmount: bidAmount,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: (result['message'] ?? 'Teklifiniz kaydedildi.').toString(),
        type: SnackbarType.success,
      );
      widget.onSuccess();
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Teklif verilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tender = widget.detail.tender;
    final playerBid = widget.detail.playerBid;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İhale Teklifi Ver',
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'En düşük geçerli teklif ihaleyi kazanır. Teminat kasanızdan ayrılır; kazanamazsanız eksiksiz iade edilir.',
            style: AppTextStyles.body.standardCopyWith(
              fontSize: AppTypography.bodySmall,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 14.h),
          if (playerBid != null) ...[
            Row(
              children: [
                Expanded(
                  child: _DetailMetric(
                    label: 'Mevcut Teklifin',
                    value: '₺${AppMoney.compact(playerBid.bidAmount)}',
                    color: AppColors.gold,
                  ),
                ),
                Expanded(
                  child: _DetailMetric(
                    label: 'Bağlanan Teminat',
                    value: '₺${AppMoney.compact(playerBid.bondPaid)}',
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Teklif Tutarı (₺)',
              hintText: tender.rewardCash.round().toString(),
              helperText: 'Tavan bütçe: ₺${AppMoney.compact(tender.rewardCash)}',
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.textOnAccent,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              icon: _isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: Center(child: AppLoadingIndicator(strokeWidth: 2)),
                    )
                  : const Icon(AppIcons.gavelRounded),
              label: Text(playerBid == null ? 'Teklifi Kaydet' : 'Teklifi Güncelle'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı Bileşenler ───────────────────────────────────────────────────────
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.micro,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.micro,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.title.standardCopyWith(
            color: color,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 1.h),
          Text(
            subtitle!,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: 9.sp,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveDeliveriesCard extends StatelessWidget {
  const _ActiveDeliveriesCard({required this.deliveries});
  final List<TenderActiveDeliveryModel> deliveries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.blue, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.localShippingRounded, size: 16, color: AppColors.gold),
              SizedBox(width: 6.w),
              Text(
                'Yoldaki Sevkiyatlar (${deliveries.length})',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...deliveries.map((delivery) {
            return Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppFx.softOverlay(0.06),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${delivery.quantity} adet • ${delivery.sourceWarehouseName}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Teslim ediliyor...',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WarehouseSelectionCard extends StatelessWidget {
  const _WarehouseSelectionCard({
    required this.detail,
    required this.selectedWarehouseId,
    required this.onSelected,
  });

  final TenderDetailModel detail;
  final String? selectedWarehouseId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = detail.warehouseOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kaynak Depo Seçimi',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6.h),
        if (options.isEmpty)
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'Bu ürün için stoğunuz bulunan aktif depo yok.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.warning,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          )
        else
          ...options.map((item) {
            final isSelected = item.warehouseId == selectedWarehouseId;
            return Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: InkWell(
                onTap: () => onSelected(item.warehouseId),
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold.withValues(alpha: 0.12) : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.gold : AppColors.textMuted,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.cityName,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Stok: ${item.availableQuantity} adet ${item.sameCity ? '(Aynı Şehir - Anlık)' : ''}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: item.sameCity ? AppColors.green : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Teslimat Miktarı',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Maks: $maxQuantity adet',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.goldLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  '$quantity adet',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            IconButton.filledTonal(
              onPressed: quantity < maxQuantity ? () => onChanged(quantity + 1) : null,
              icon: const Icon(Icons.add),
            ),
            SizedBox(width: 8.w),
            FilledButton.tonal(
              onPressed: maxQuantity > 0 ? () => onChanged(maxQuantity) : null,
              child: const Text('Maks'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleSelectionCard extends StatelessWidget {
  const _VehicleSelectionCard({
    required this.optionsAsync,
    required this.selectedVehicleId,
    required this.onSelected,
  });

  final AsyncValue<TransferVehicleOptionsResult<TenderVehicleOptionModel>>? optionsAsync;
  final String? selectedVehicleId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (optionsAsync == null) return const SizedBox.shrink();

    return optionsAsync!.when(
      loading: () => Center(child: AppLoadingIndicator(color: AppColors.gold)),
      error: (err, _) => Text('Araç seçenekleri yüklenemedi: $err', style: TextStyle(color: AppColors.red)),
      data: (result) {
        if (result.options.isEmpty) {
          return Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              result.unavailableReason ?? 'Bu rota için uygun araç bulunamadı.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.red,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nakliye Aracı Seçimi',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!result.hasSelectableOptions && result.unavailableReason != null) ...[
              SizedBox(height: 6.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  result.unavailableReason!,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            SizedBox(height: 8.h),
            ...() {
              final displayOptions = result.options.take(8).toList();
              String? cheapestVehicleId;
              String? fastestVehicleId;
              double minPrice = double.infinity;
              int minDuration = 0x7FFFFFFF;

              for (final opt in displayOptions) {
                if (opt.canSelect) {
                  final price = opt.transportCost > 0
                      ? opt.transportCost
                      : (opt.rentalCost + opt.fuelCost);
                  if (price < minPrice) {
                    minPrice = price;
                    cheapestVehicleId = opt.vehicleId;
                  }
                  if (opt.estimatedDurationSeconds > 0 &&
                      opt.estimatedDurationSeconds < minDuration) {
                    minDuration = opt.estimatedDurationSeconds;
                    fastestVehicleId = opt.vehicleId;
                  }
                }
              }

              return displayOptions.map((option) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    speedKmh: option.speedKmh,
                    distanceKm: option.distanceKm,
                    durationLabel:
                        '${(option.estimatedDurationSeconds / 60).ceil()} dk',
                    transportCost: option.transportCost,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: option.vehicleId == selectedVehicleId,
                    isBestPrice: option.vehicleId == cheapestVehicleId,
                    isFastest: option.vehicleId == fastestVehicleId,
                    disabledReason: option.disabledReason,
                    onTap: () => onSelected(option.vehicleId),
                  ),
                );
              });
            }(),
          ],
        );
      },
    );
  }
}

class _DeliveryProfitCalculator extends StatelessWidget {
  const _DeliveryProfitCalculator({
    required this.quantity,
    required this.unitRewardCash,
    required this.unitCost,
    required this.isCostEstimated,
    required this.sameCity,
    required this.transportCost,
  });

  final int quantity;
  final double unitRewardCash;
  final double unitCost;
  final bool isCostEstimated;
  final bool sameCity;
  final double transportCost;

  @override
  Widget build(BuildContext context) {
    final totalRevenue = quantity * unitRewardCash;
    final totalCost = (quantity * unitCost) + (sameCity ? 0.0 : transportCost);
    final netProfit = totalRevenue - totalCost;
    final isProfitable = netProfit > 0;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: (isProfitable ? AppColors.green : AppColors.warning).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: (isProfitable ? AppColors.green : AppColors.warning).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tahmini Gelir:', style: AppTextStyles.caption),
              Text('₺${AppMoney.compact(totalRevenue)}', style: AppTextStyles.caption.standardCopyWith(color: AppColors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          if (!sameCity && transportCost > 0) ...[
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nakliye Masrafı:', style: AppTextStyles.caption),
                Text('-₺${AppMoney.compact(transportCost)}', style: AppTextStyles.caption.standardCopyWith(color: AppColors.red)),
              ],
            ),
          ],
          SizedBox(height: 4.h),
          Divider(color: AppFx.softOverlay(0.1), height: 1),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tahmini Net Kazanç:',
                style: AppTextStyles.body.standardCopyWith(
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${isProfitable ? '+' : ''}₺${AppMoney.compact(netProfit)}',
                style: AppTextStyles.body.standardCopyWith(
                  color: isProfitable ? AppColors.green : AppColors.warning,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
