import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';

class TaxScreen extends ConsumerStatefulWidget {
  const TaxScreen({super.key});

  @override
  ConsumerState<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends ConsumerState<TaxScreen> {
  final TextEditingController _customAmountController = TextEditingController();
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    // Invalidate tax and player providers on screen enter to always load freshest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(taxDebtProvider);
      ref.invalidate(playerTaxProvider);
    });
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  double _resolvePayableAmount({
    required double requestedAmount,
    required double currentDebt,
  }) {
    if (requestedAmount <= 0 || currentDebt <= 0) {
      return 0.0;
    }
    return requestedAmount > currentDebt ? currentDebt : requestedAmount;
  }

  double? _parseCustomAmount() {
    final normalizedText = _customAmountController.text.trim().replaceAll(',', '.');
    return double.tryParse(normalizedText);
  }

  Future<void> _handlePayment(double requestedAmount, double currentDebt) async {
    final isPayAll = requestedAmount == -1;
    final amount = isPayAll
        ? currentDebt
        : _resolvePayableAmount(
            requestedAmount: requestedAmount,
            currentDebt: currentDebt,
          );

    if (amount <= 0) {
      AppSnackbar.show(context, message: 'Lütfen geçerli bir tutar girin.', type: SnackbarType.error);
      return;
    }

    final player = ref.read(playerProvider).value;
    if (player == null) return;

    if (player.cash < amount) {
      AppSnackbar.show(context, message: 'Yetersiz nakit bakiye.', type: SnackbarType.error);
      return;
    }

    setState(() {
      _isPaying = true;
    });

    final notifier = ref.read(taxActionProvider);
    final result = await notifier.payTax(isPayAll ? -1 : amount);

    if (mounted) {
      setState(() {
        _isPaying = false;
      });

      if (result['success'] == true) {
        // If pay all, use the actual amount paid returned from the server for the UI floating feedback
        final actualPaid = (result['paid_amount'] as num?)?.toDouble() ?? amount;
        FloatingFeedback.show(
          context,
          amount: actualPaid,
          type: FloatingFeedbackType.cashRemove,
        );
        AppSnackbar.show(context, message: result['message'] ?? 'Ödeme başarılı.', type: SnackbarType.success);
        _customAmountController.clear();
      } else {
        AppSnackbar.show(context, message: result['message'] ?? 'Odeme sirasinda hata olustu.', type: SnackbarType.error);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final taxDebtAsync = ref.watch(taxDebtProvider);
    final playerAsync = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Vergi Kurumu'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: taxDebtAsync.when(
                  loading: () => Center(
                    child: AppLoadingIndicator(color: AppColors.gold),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'Vergi borcu bilgisi alınamadı.\n$err',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
                      ),
                    ),
                  ),
                  data: (taxDebt) => playerAsync.when(
                    loading: () => Center(
                      child: AppLoadingIndicator(color: AppColors.gold),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Text(
                          'Vergi borcu bilgisi alınamadı.\n$err',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
                        ),
                      ),
                    ),
                    data: (player) {
                      final hasDebt = taxDebt > 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTaxSummaryCard(taxDebt, hasDebt),
                          SizedBox(height: 16.h),
                          if (hasDebt) ...[
                            _buildPaymentSection(taxDebt, player?.cash ?? 0.0),
                          ] else ...[
                            _buildNoDebtCard(),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxSummaryCard(double taxDebt, bool hasDebt) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppDecorations.premiumCard(
        hasDebt ? AppColors.red : AppColors.borderGold,
        20.r,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: (hasDebt ? AppColors.red : AppColors.green)
                  .withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: (hasDebt ? AppColors.red : AppColors.green)
                    .withValues(alpha: 0.35),
                width: 1.5.r,
              ),
            ),
            child: Icon(
              AppIcons.assuredWorkloadRounded,
              color: hasDebt ? AppColors.red : AppColors.green,
              size: AppIconSizes.displayLarge,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'BİRİKMİŞ VERGİ BORCU',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            AppMoney.full(taxDebt, decimals: 2),
            style: AppTextStyles.h2.standardCopyWith(
              color: hasDebt ? AppColors.red : AppColors.green,
              fontSize: AppTypography.hero,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: (hasDebt ? AppColors.red : AppColors.green)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(
                color: (hasDebt ? AppColors.red : AppColors.green)
                    .withValues(alpha: 0.35),
                width: 1.r,
              ),
            ),
            child: Text(
              hasDebt ? 'VERGİ BORCUNUZ BULUNMAKTADIR' : 'VERGİ BORCUNUZ TEMİZ',
              style: AppTextStyles.caption.standardCopyWith(
                color: hasDebt ? AppColors.red : AppColors.green,
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDebtCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppDecorations.premiumCard(AppColors.green, 16.r),
      child: Column(
        children: [
          Icon(
            AppIcons.sentimentVerySatisfiedRounded,
            color: AppColors.green,
            size: AppIconSizes.displayLarge,
          ),
          SizedBox(height: 10.h),
          Text(
            'Tebrikler!',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Mevcut tüm vergileriniz ödenmiş durumdadır. Devlete borcunuz bulunmuyor.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(double taxDebt, double playerCash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ODEME YAP',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.gold,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 8.h),
        // Quick payment buttons
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 8.w,
          mainAxisSpacing: 8.h,
          childAspectRatio: 2.8,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickPaymentButton('10,000 TL', 10000.0, playerCash, taxDebt),
            _buildQuickPaymentButton('50,000 TL', 50000.0, playerCash, taxDebt),
            _buildQuickPaymentButton('100,000 TL', 100000.0, playerCash, taxDebt),
            _buildQuickPaymentButton('BORCUN HEPSINI ODE', -1, playerCash, taxDebt, isPrimary: true),
          ],
        ),
        SizedBox(height: 16.h),
        // Custom payment amount
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'OZEL ODEME TUTARI',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _customAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Tutar (TL)',
                  labelStyle: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: _isPaying
                    ? null
                    : () {
                        final val = _parseCustomAmount();
                        if (val != null) {
                          _handlePayment(val, taxDebt);
                        } else {
                          AppSnackbar.show(context, message: 'Lütfen geçerli bir sayı girin.', type: SnackbarType.error);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: _isPaying
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: AppLoadingIndicator(
                          strokeWidth: 2.0,
                          color: AppColors.textOnAccent,
                        ),
                      )
                    : Text(
                        'Odemeyi Onayla',
                        style: AppTextStyles.body.standardCopyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPaymentButton(
    String label,
    double amount,
    double playerCash,
    double currentDebt, {
    bool isPrimary = false,
  }) {
    final isPayAll = amount == -1;
    final payableAmount = isPayAll
        ? currentDebt
        : _resolvePayableAmount(
            requestedAmount: amount,
            currentDebt: currentDebt,
          );
    final bool canPay = playerCash >= payableAmount && payableAmount > 0;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: (canPay && !_isPaying)
            ? () => _handlePayment(amount, currentDebt)
            : null,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            color: isPrimary
                ? (canPay ? AppColors.gold : AppColors.gold.withValues(alpha: 0.3))
                : AppColors.cardBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isPrimary
                  ? (canPay ? AppColors.goldLight : AppColors.border)
                  : AppColors.border.withValues(alpha: 0.5),
              width: 1.r,
            ),
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.standardCopyWith(
                  color: isPrimary
                      ? AppColors.textOnAccent
                      : (canPay ? AppColors.textPrimary : AppColors.textMuted),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!isPrimary) ...[
                SizedBox(height: 2.h),
                Text(
                  canPay ? 'Nakit Yeterli' : 'Yetersiz Nakit',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: canPay ? AppColors.green : AppColors.red,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
