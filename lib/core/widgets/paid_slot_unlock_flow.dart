import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/data/slot_unlock_quote_provider.dart';
import 'package:hard_kapitalizm/core/models/slot_unlock_quote_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

/// Shared paid-slot flow for Store / Field / Farm / Factory / Mine.
/// The backend quote is always fetched immediately before confirmation, so the
/// UI never relies on a hard-coded slot price or stale cash/tax state.
class PaidSlotUnlockFlow {
  const PaidSlotUnlockFlow._();

  static Future<Map<String, dynamic>?> run({
    required BuildContext context,
    required WidgetRef ref,
    required String buildingKind,
    required String entityId,
    required Future<Map<String, dynamic>> Function() onUnlock,
  }) async {
    SlotUnlockQuoteModel quote;
    try {
      quote = await ref.read(
        slotUnlockQuoteProvider(
          (buildingKind: buildingKind, entityId: entityId),
        ).future,
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Slot bilgisi alınamadı',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    if (!quote.success || !quote.canUnlock) {
      AppSnackbar.show(
        context,
        title: 'Yeni slot açılamıyor',
        message: _blockMessage(quote),
        type: SnackbarType.info,
      );
      return null;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Yeni Üretim Slotu',
          style: AppTextStyles.h2.standardCopyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${quote.name.isEmpty ? 'İşletme' : quote.name} için '
              '${quote.nextSlotIndex}. slot açılacak.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 14.h),
            _QuoteRow(
              label: 'Slot',
              value: '${quote.currentSlotCount + 1} / ${quote.maxSlotCount}',
            ),
            SizedBox(height: 8.h),
            _QuoteRow(
              label: 'Açılış maliyeti',
              value: AppMoney.compact(quote.cashCost ?? 0),
              accent: AppColors.gold,
            ),
            SizedBox(height: 8.h),
            _QuoteRow(
              label: 'Mevcut nakit',
              value: AppMoney.compact(quote.playerCash),
              accent: quote.hasRequiredCash ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: const Text('SLOTU AÇ'),
          ),
        ],
      ),
    );

    if (approved != true || !context.mounted) return null;

    final result = await onUnlock();
    if (!context.mounted) return result;

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Slot açıldı',
        message: '${quote.nextSlotIndex}. üretim slotu kullanıma hazır.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Slot açılamadı',
        message: result['message']?.toString() ?? 'İşlem tamamlanamadı.',
        type: SnackbarType.error,
      );
    }
    return result;
  }

  static String _blockMessage(SlotUnlockQuoteModel quote) {
    switch (quote.blockReason) {
      case 'maximum_slots':
        return 'Bu işletmede maksimum slot sayısına ulaşıldı.';
      case 'tax_blocked':
        return 'Vergi borcu nedeniyle yeni yatırım yapılamıyor.';
      case 'cash':
        return 'Yeni slot için yeterli nakit bulunmuyor.';
      default:
        return 'Yeni slot şu anda açılamıyor.';
    }
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: accent ?? AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
