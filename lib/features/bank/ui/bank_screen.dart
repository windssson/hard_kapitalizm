import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/bank/data/bank_provider.dart';
import 'package:hard_kapitalizm/features/bank/models/loan_model.dart';
import 'package:hard_kapitalizm/features/bank/models/deposit_model.dart';

class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _depositAmountController =
      TextEditingController();

  int _selectedLoanInstallments = 12; // Default 12 installments
  int _selectedDepositDays = 3; // Default 3 days lock

  bool _isProcessingLoan = false;
  bool _isProcessingDeposit = false;

  @override
  void dispose() {
    _loanAmountController.dispose();
    _depositAmountController.dispose();
    super.dispose();
  }

  double _getInterestRate(int installments) {
    if (installments == 6) return 0.05;
    if (installments == 12) return 0.12;
    if (installments == 24) return 0.28;
    return 0.45;
  }

  double _getDepositRate(int days) {
    if (days == 1) return 0.01;
    if (days == 3) return 0.04;
    return 0.10;
  }

  String _formatDateTime(DateTime value) {
    final safe = value.toLocal();
    final day = safe.day.toString().padLeft(2, '0');
    final month = safe.month.toString().padLeft(2, '0');
    final hour = safe.hour.toString().padLeft(2, '0');
    final minute = safe.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.isNegative) return '00:00:00';

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (days > 0) {
      return '$days gün $hStr:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  Future<void> _handleTakeLoan(double limit, double activeDebtTotal) async {
    final amount = double.tryParse(_loanAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Lütfen geçerli bir kredi tutarı girin.',
        type: SnackbarType.error,
      );
      return;
    }

    if (activeDebtTotal + amount > limit) {
      AppSnackbar.show(
        context,
        message: 'Kredi limiti aşılamaz.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isProcessingLoan = true);
    final result = await ref
        .read(bankActionProvider)
        .takeLoan(amount, _selectedLoanInstallments);
    setState(() => _isProcessingLoan = false);

    if (mounted) {
      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: amount,
          type: FloatingFeedbackType.cashAdd,
        );
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Kredi çekildi.',
          type: SnackbarType.success,
        );
        _loanAmountController.clear();
      } else {
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Kredi çekme sırasında hata oluştu.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handlePayInstallment(LoanModel loan) async {
    final player = ref.read(playerProvider).value;
    if (player == null) return;

    if (player.cash < loan.installmentAmount) {
      AppSnackbar.show(
        context,
        message: 'Yetersiz nakit bakiye.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isProcessingLoan = true);
    final result = await ref
        .read(bankActionProvider)
        .payLoanInstallment(loan.id);
    setState(() => _isProcessingLoan = false);

    if (mounted) {
      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: loan.installmentAmount,
          type: FloatingFeedbackType.cashRemove,
        );
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Taksit ödendi.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Taksit ödeme sırasında hata oluştu.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleCreateDeposit(double playerCash) async {
    final amount = double.tryParse(_depositAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Lütfen geçerli bir mevduat tutarı girin.',
        type: SnackbarType.error,
      );
      return;
    }

    if (amount > playerCash) {
      AppSnackbar.show(
        context,
        message: 'Yetersiz bakiye.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isProcessingDeposit = true);
    final result = await ref
        .read(bankActionProvider)
        .createDeposit(amount, _selectedDepositDays);
    setState(() => _isProcessingDeposit = false);

    if (mounted) {
      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: amount,
          type: FloatingFeedbackType.cashRemove,
        );
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Vadeli hesap açıldı.',
          type: SnackbarType.success,
        );
        _depositAmountController.clear();
      } else {
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Hesap açma sırasında hata oluştu.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleClaimDeposit(DepositModel deposit) async {
    setState(() => _isProcessingDeposit = true);
    final result = await ref.read(bankActionProvider).claimDeposit(deposit.id);
    setState(() => _isProcessingDeposit = false);

    if (mounted) {
      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: deposit.expectedPayout,
          type: FloatingFeedbackType.cashAdd,
        );
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Mevduat tahsil edildi.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Tahsilat sırasında hata oluştu.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleWithdrawEarly(DepositModel deposit) async {
    final penalty = deposit.amount * 0.05;
    final payout = deposit.amount - penalty;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Text(
          'Erken Kapatma Onayı',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Vadeli mevduat hesabınızı vadesinden önce kapatmak istiyorsunuz.\n\n'
          '• Kazanılan tüm faiz hakkı kaybolacaktır.\n'
          '• %5 anapara cezası uygulanacaktır (${AppMoney.full(penalty)} kesinti).\n'
          '• Hesabınıza aktarılacak tutar: ${AppMoney.full(payout)}.\n\n'
          'Onaylıyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.label.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCore,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: const Text('Erken Kapat'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingDeposit = true);
    final result = await ref
        .read(bankActionProvider)
        .withdrawDepositEarly(deposit.id);
    setState(() => _isProcessingDeposit = false);

    if (mounted) {
      if (result['success'] == true) {
        FloatingFeedback.show(
          context,
          amount: payout,
          type: FloatingFeedbackType.cashAdd,
        );
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'Mevduat erken kapatıldı.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: result['message'] ?? 'İşlem sırasında hata oluştu.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        appBar: const SecondaryTopBar(title: 'Banka Kurumu'),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: AppColors.cardBg,
                child: TabBar(
                  indicatorColor: AppColors.gold,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(
                      icon: Icon(AppIcons.paymentsRounded),
                      text: 'Taksitli Kredi',
                    ),
                    Tab(
                      icon: Icon(AppIcons.accountBalanceWallet),
                      text: 'Vadeli Mevduat',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildLoanTab(), _buildDepositTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanTab() {
    final loanLimitAsync = ref.watch(loanLimitProvider);
    final loansAsync = ref.watch(playerLoansProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loan Status Summary Card
          loanLimitAsync.when(
            loading: () =>
                Center(child: AppLoadingIndicator(color: AppColors.gold)),
            error: (err, _) => Text(
              'Hata: $err',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
            ),
            data: (limit) => loansAsync.when(
              loading: () =>
                  Center(child: AppLoadingIndicator(color: AppColors.gold)),
              error: (err, _) => Text(
                'Hata: $err',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.red,
                ),
              ),
              data: (loans) {
                final activeLoans = loans
                    .where((l) => l.status != 'paid')
                    .toList();
                final activeDebtTotal = activeLoans.fold<double>(
                  0,
                  (sum, l) => sum + (l.totalDue - l.totalPaid),
                );
                final remainingLimit = (limit - activeDebtTotal).clamp(
                  0.0,
                  limit,
                );

                return Column(
                  children: [
                    _buildSummaryCard(
                      title: 'KREDİ LİMİTİ DURUMU',
                      primaryVal: AppMoney.full(limit),
                      secondaryVal:
                          'Kalan Limit: ${AppMoney.full(remainingLimit)}',
                      activeDebt: activeDebtTotal,
                      progress: limit > 0
                          ? (activeDebtTotal / limit).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                    SizedBox(height: 16.h),
                    _buildNewLoanSection(remainingLimit, activeDebtTotal),
                    SizedBox(height: 24.h),
                    _buildActiveLoansList(activeLoans),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String primaryVal,
    required String secondaryVal,
    required double activeDebt,
    required double progress,
  }) {
    final isDanger = progress > 0.8;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(
        activeDebt > 0
            ? (isDanger ? AppColors.red : AppColors.gold)
            : AppColors.cardBorder,
        14.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (activeDebt > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: AppDecorations.badge(
                    bgColor: AppColors.dangerCore.withValues(alpha: 0.1),
                    borderColor: AppColors.dangerCore.withValues(alpha: 0.3),
                    radius: 4.r,
                  ),
                  child: Text(
                    'Borçlu',
                    style: AppTextStyles.badgeText.standardCopyWith(
                      color: AppColors.dangerCore,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            primaryVal,
            style: AppTextStyles.largeTitle.standardCopyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                secondaryVal,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (activeDebt > 0)
                Text(
                  'Aktif Borç: ${AppMoney.full(activeDebt)}',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (activeDebt > 0) ...[
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6.h,
                backgroundColor: AppColors.cardBgLight,
                color: isDanger ? AppColors.dangerCore : AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewLoanSection(double remainingLimit, double activeDebtTotal) {
    final double interestRate = _getInterestRate(_selectedLoanInstallments);
    final double amount =
        double.tryParse(_loanAmountController.text.trim()) ?? 0.0;
    final double totalDue = amount * (1.0 + interestRate);
    final double installmentAmount = amount > 0
        ? (totalDue / _selectedLoanInstallments)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Yeni Kredi Çek',
            style: AppTextStyles.titleBold.standardCopyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _loanAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.input,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Çekmek istediğiniz tutar',
              suffixText: '₺',
              suffixIcon: IconButton(
                icon: Icon(Icons.arrow_circle_up, color: AppColors.gold),
                onPressed: () {
                  _loanAmountController.text = remainingLimit
                      .toInt()
                      .toString();
                  setState(() {});
                },
                tooltip: 'Maksimum Kredi',
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Geri Ödeme Süresi (Günlük Taksit)',
            style: AppTextStyles.label.standardCopyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [6, 12, 24, 36].map((days) {
              final isSelected = _selectedLoanInstallments == days;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedLoanInstallments = days;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : AppColors.transparent,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5.w : 1.w,
                      ),
                    ),
                    child: Text(
                      '$days Gün\n(%${(_getInterestRate(days) * 100).toInt()})',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.standardCopyWith(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.cardBorder, width: 0.5.w),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Kredi Faiz Oranı',
                  '%${(interestRate * 100).toInt()}',
                ),
                SizedBox(height: 6.h),
                _buildInfoRow('Toplam Geri Ödeme', AppMoney.full(totalDue)),
                SizedBox(height: 6.h),
                _buildInfoRow(
                  'Günlük Taksit Tutarı',
                  AppMoney.full(installmentAmount),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed:
                _isProcessingLoan ||
                    amount <= 0 ||
                    (activeDebtTotal + amount >
                        remainingLimit + activeDebtTotal)
                ? null
                : () => _handleTakeLoan(
                    remainingLimit + activeDebtTotal,
                    activeDebtTotal,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.cardBgLight,
            ),
            child: _isProcessingLoan
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      color: AppColors.textOnAccent,
                    ),
                  )
                : const Text('Krediyi Onayla ve Çek'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLoansList(List<LoanModel> loans) {
    if (loans.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Icon(
              AppIcons.paymentsRounded,
              color: AppColors.textMuted,
              size: 36.r,
            ),
            SizedBox(height: 8.h),
            Text(
              'Aktif kredi borcunuz bulunmuyor.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aktif Kredi Borçlarınız',
          style: AppTextStyles.titleBold.standardCopyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: loans.length,
          separatorBuilder: (_, _) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final loan = loans[index];
            final remaining = loan.totalDue - loan.totalPaid;
            final isDefaulted = loan.status == 'defaulted';

            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: AppDecorations.premiumCard(
                isDefaulted ? AppColors.red : AppColors.cardBorder,
                12.r,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kredi (${loan.installmentsTotal} Taksit)',
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isDefaulted)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.dangerCore.withValues(
                              alpha: 0.15,
                            ),
                            borderColor: AppColors.dangerCore,
                            radius: 4.r,
                          ),
                          child: Text(
                            'TEMERRÜT / GECİKME',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.dangerCore,
                              fontSize: 9.sp,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.gold.withValues(alpha: 0.1),
                            borderColor: AppColors.gold,
                            radius: 4.r,
                          ),
                          child: Text(
                            'Ödeniyor',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 9.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildInfoRow('Ana Kredi Tutarı', AppMoney.full(loan.amount)),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Toplam Geri Ödeme',
                    AppMoney.full(loan.totalDue),
                  ),
                  SizedBox(height: 4.h),
                  _buildInfoRow('Ödenen Toplam', AppMoney.full(loan.totalPaid)),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Kalan Toplam Borç',
                    AppMoney.full(remaining),
                    valColor: isDefaulted
                        ? AppColors.red
                        : AppColors.textPrimary,
                  ),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Taksit Durumu',
                    '${loan.installmentsPaid} / ${loan.installmentsTotal} Gün',
                  ),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Sonraki Taksit Tarihi',
                    _formatDateTime(loan.nextInstallmentDueAt),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: _isProcessingLoan
                        ? null
                        : () => _handlePayInstallment(loan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDefaulted
                          ? AppColors.dangerCore
                          : AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: Size(double.infinity, 38.h),
                    ),
                    child: _isProcessingLoan
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5.w,
                              color: AppColors.textOnAccent,
                            ),
                          )
                        : Text(
                            'Manuel Taksit Öde (${AppMoney.full(loan.installmentAmount)})',
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDepositTab() {
    final depositsAsync = ref.watch(playerDepositsProvider);
    final playerAsync = ref.watch(playerProvider);

    return playerAsync.when(
      loading: () => Center(child: AppLoadingIndicator(color: AppColors.gold)),
      error: (err, _) => Text(
        'Hata: $err',
        style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
      ),
      data: (player) {
        if (player == null) return const SizedBox.shrink();

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: depositsAsync.when(
            loading: () =>
                Center(child: AppLoadingIndicator(color: AppColors.gold)),
            error: (err, _) => Text(
              'Hata: $err',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
            ),
            data: (deposits) {
              final activeDeposits = deposits
                  .where((d) => d.status == 'active')
                  .toList();
              final totalActiveDeposits = activeDeposits.fold<double>(
                0,
                (sum, d) => sum + d.amount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Deposit Status Card
                  _buildSummaryCard(
                    title: 'VADELİ MEVDUAT DURUMU',
                    primaryVal: AppMoney.full(player.cash),
                    secondaryVal:
                        'Toplam Aktif Yatırım: ${AppMoney.full(totalActiveDeposits)}',
                    activeDebt: 0,
                    progress: 0,
                  ),
                  SizedBox(height: 16.h),
                  _buildNewDepositSection(player.cash),
                  SizedBox(height: 24.h),
                  _buildActiveDepositsList(deposits),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewDepositSection(double playerCash) {
    final double interestRate = _getDepositRate(_selectedDepositDays);
    final double amount =
        double.tryParse(_depositAmountController.text.trim()) ?? 0.0;
    final double payoutGain = amount * interestRate;
    final double expectedPayout = amount * (1.0 + interestRate);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vadeli Hesap Aç',
            style: AppTextStyles.titleBold.standardCopyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _depositAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.input,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Yatırmak istediğiniz tutar',
              suffixText: '₺',
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [0.25, 0.50, 1.0].map((pct) {
              return Padding(
                padding: EdgeInsets.only(left: 6.w),
                child: TextButton(
                  onPressed: () {
                    _depositAmountController.text = (playerCash * pct)
                        .toInt()
                        .toString();
                    setState(() {});
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    backgroundColor: AppColors.cardBgLight.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: Text(
                    pct == 1.0 ? 'HEPSİ' : '%${(pct * 100).toInt()}',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          Text(
            'Vade Süresi (Gün)',
            style: AppTextStyles.label.standardCopyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [1, 3, 7].map((days) {
              final isSelected = _selectedDepositDays == days;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDepositDays = days;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : AppColors.transparent,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5.w : 1.w,
                      ),
                    ),
                    child: Text(
                      '$days Gün\n(%${(_getDepositRate(days) * 100).toInt()})',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.standardCopyWith(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.cardBorder, width: 0.5.w),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Mevduat Faiz Oranı',
                  '%${(interestRate * 100).toInt()}',
                ),
                SizedBox(height: 6.h),
                _buildInfoRow(
                  'Vade Sonu Faiz Kazancı',
                  '+${AppMoney.full(payoutGain)}',
                ),
                SizedBox(height: 6.h),
                _buildInfoRow(
                  'Toplam Vade Sonu ',
                  AppMoney.full(expectedPayout),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed:
                _isProcessingDeposit || amount <= 0 || amount > playerCash
                ? null
                : () => _handleCreateDeposit(playerCash),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.cardBgLight,
            ),
            child: _isProcessingDeposit
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      color: AppColors.textOnAccent,
                    ),
                  )
                : const Text('Vadeli Mevduat Hesabını Aç'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDepositsList(List<DepositModel> deposits) {
    if (deposits.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Icon(
              AppIcons.accountBalanceWallet,
              color: AppColors.textMuted,
              size: 36.r,
            ),
            SizedBox(height: 8.h),
            Text(
              'Aktif mevduat yatırımınız bulunmuyor.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final nowTime = ref.watch(secondTickerProvider).value ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mevduat Hesaplarınız',
          style: AppTextStyles.titleBold.standardCopyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deposits.length,
          separatorBuilder: (_, _) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final deposit = deposits[index];
            final isClaimed = deposit.status == 'claimed';
            final isEarlyWithdrawn = deposit.status == 'withdrawn_early';
            final isCompleted = deposit.lockedUntil.isBefore(nowTime);

            final remainingDuration = deposit.lockedUntil.difference(nowTime);

            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: AppDecorations.premiumCard(
                deposit.status == 'active'
                    ? (isCompleted ? AppColors.green : AppColors.gold)
                    : AppColors.cardBorder,
                12.r,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vadeli Yatırım (%%%${(deposit.interestRate * 100).toInt()})',
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isClaimed)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.cardBgLight.withValues(
                              alpha: 0.1,
                            ),
                            borderColor: AppColors.cardBorder,
                            radius: 4.r,
                          ),
                          child: Text(
                            'TAHSİL EDİLDİ',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: 9.sp,
                            ),
                          ),
                        )
                      else if (isEarlyWithdrawn)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.dangerCore.withValues(
                              alpha: 0.05,
                            ),
                            borderColor: AppColors.cardBorder,
                            radius: 4.r,
                          ),
                          child: Text(
                            'ERKEN KAPATILDI',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.dangerCore,
                              fontSize: 9.sp,
                            ),
                          ),
                        )
                      else if (isCompleted)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.green.withValues(alpha: 0.1),
                            borderColor: AppColors.green,
                            radius: 4.r,
                          ),
                          child: Text(
                            'VADE DOLDU',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.green,
                              fontSize: 9.sp,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: AppDecorations.badge(
                            bgColor: AppColors.gold.withValues(alpha: 0.1),
                            borderColor: AppColors.gold,
                            radius: 4.r,
                          ),
                          child: Text(
                            'Kilitli',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 9.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildInfoRow(
                    'Yatırılan Tutar',
                    AppMoney.full(deposit.amount),
                  ),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Vade Sonu Alacak',
                    AppMoney.full(deposit.expectedPayout),
                    valColor: isClaimed ? AppColors.textMuted : AppColors.green,
                  ),
                  SizedBox(height: 4.h),
                  _buildInfoRow(
                    'Vade Bitiş Tarihi',
                    _formatDateTime(deposit.lockedUntil),
                  ),
                  if (deposit.status == 'active') ...[
                    SizedBox(height: 4.h),
                    _buildInfoRow(
                      isCompleted ? 'Tahsil Süresi' : 'Kalan Süre',
                      isCompleted
                          ? 'Vade tamamlandı'
                          : _formatRemainingTime(remainingDuration),
                      valColor: isCompleted ? AppColors.green : AppColors.gold,
                    ),
                    SizedBox(height: 12.h),
                    if (isCompleted)
                      ElevatedButton(
                        onPressed: _isProcessingDeposit
                            ? null
                            : () => _handleClaimDeposit(deposit),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.textOnAccent,
                          minimumSize: Size(double.infinity, 38.h),
                        ),
                        child: _isProcessingDeposit
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5.w,
                                  color: AppColors.textOnAccent,
                                ),
                              )
                            : const Text('Kazancı Tahsil Et'),
                      )
                    else
                      OutlinedButton(
                        onPressed: _isProcessingDeposit
                            ? null
                            : () => _handleWithdrawEarly(deposit),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerCore,
                          side: BorderSide(
                            color: AppColors.dangerCore.withValues(alpha: 0.5),
                          ),
                          minimumSize: Size(double.infinity, 38.h),
                        ),
                        child: _isProcessingDeposit
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5.w,
                                  color: AppColors.dangerCore,
                                ),
                              )
                            : const Text('Vadesinden Önce Kapat (Erken Çekim)'),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodySmall,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: valColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }
}
