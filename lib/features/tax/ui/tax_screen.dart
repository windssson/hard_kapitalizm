import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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
    final amount = _resolvePayableAmount(
      requestedAmount: requestedAmount,
      currentDebt: currentDebt,
    );

    if (amount <= 0) {
      AppSnackbar.show(context, message: 'Lutfen gecerli bir tutar girin.', type: SnackbarType.error);
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
    final result = await notifier.payTax(amount);

    if (mounted) {
      setState(() {
        _isPaying = false;
      });

      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: amount,
          type: FloatingFeedbackType.cashRemove,
        );
        AppSnackbar.show(context, message: result['message'] ?? 'Odeme basarili.', type: SnackbarType.success);
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
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
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
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'Vergi borcu bilgisi alinamadi.\n$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                  ),
                  data: (taxDebt) => playerAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Text(
                          'Vergi borcu bilgisi alinamadi.\n$err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.red),
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
              Icons.assured_workload_rounded,
              color: hasDebt ? AppColors.red : AppColors.green,
              size: 40.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'BIRIKMIS VERGI BORCU',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            AppMoney.full(taxDebt, decimals: 2),
            style: TextStyle(
              color: hasDebt ? AppColors.red : AppColors.green,
              fontSize: 26.sp,
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
              hasDebt ? 'VERGI BORCUNUZ BULUNMAKTADIR' : 'VERGI BORCUNUZ TEMIZ',
              style: TextStyle(
                color: hasDebt ? AppColors.red : AppColors.green,
                fontSize: 9.sp,
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
            Icons.sentiment_very_satisfied_rounded,
            color: AppColors.green,
            size: 44.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            'Tebrikler!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Mevcut tum vergileriniz odenmis durumdadir. Devlete borcunuz bulunmuyor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
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
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 11.sp,
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
            _buildQuickPaymentButton('BORCUN HEPSINI ODE', taxDebt, playerCash, taxDebt, isPrimary: true),
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
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9.sp,
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Tutar (TL)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.gold),
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
                          AppSnackbar.show(context, message: 'Lutfen gecerli bir sayi girin.', type: SnackbarType.error);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: _isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Odemeyi Onayla',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
    final payableAmount = _resolvePayableAmount(
      requestedAmount: amount,
      currentDebt: currentDebt,
    );
    final bool canPay = playerCash >= payableAmount && payableAmount > 0;

    return Material(
      color: Colors.transparent,
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
                style: TextStyle(
                  color: isPrimary
                      ? Colors.black
                      : (canPay ? AppColors.textPrimary : AppColors.textMuted),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!isPrimary) ...[
                SizedBox(height: 2.h),
                Text(
                  canPay ? 'Nakit Yeterli' : 'Yetersiz Nakit',
                  style: TextStyle(
                    color: canPay ? AppColors.green : AppColors.red,
                    fontSize: 8.sp,
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
