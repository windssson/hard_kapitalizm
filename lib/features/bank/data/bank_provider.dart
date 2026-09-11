import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/bank/models/loan_model.dart';
import 'package:hard_kapitalizm/features/bank/models/deposit_model.dart';

class PlayerLoansNotifier extends AsyncNotifier<List<LoanModel>> {
  @override
  Future<List<LoanModel>> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await supabase
          .from('player_loans')
          .select()
          .eq('player_id', user.id);

      return (response as List<dynamic>)
          .map((json) => LoanModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Exception('Krediler alınamadı: $e'), stackTrace);
    }
  }

  void patchPayInstallment(String loanId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((loan) {
      if (loan.id == loanId) {
        final newPaid = loan.installmentsPaid + 1;
        final isCompleted = newPaid >= loan.installmentsTotal;
        return loan.copyWith(
          installmentsPaid: newPaid,
          totalPaid: loan.totalPaid + loan.installmentAmount,
          status: isCompleted ? 'paid' : loan.status,
        );
      }
      return loan;
    }).toList();

    state = AsyncData(updated);
  }

  void patchPayFull(String loanId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((loan) {
      if (loan.id == loanId) {
        return loan.copyWith(
          installmentsPaid: loan.installmentsTotal,
          totalPaid: loan.totalDue,
          status: 'paid',
        );
      }
      return loan;
    }).toList();

    state = AsyncData(updated);
  }

  void insertLoan(LoanModel loan) {
    final current = state.value;
    if (current == null) {
      // Do not turn an unloaded multi-row provider into a fake one-item cache.
      // Re-run the authoritative fetch after the committed mutation instead.
      ref.invalidateSelf();
      return;
    }
    if (current.any((l) => l.id == loan.id)) return;
    state = AsyncData([loan, ...current]);
  }

  void patchLoanChanges(String loanId, Map<String, dynamic> changes) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((loan) {
      if (loan.id == loanId) {
        return loan.copyWith(
          amount: (changes['amount'] as num?)?.toDouble() ?? loan.amount,
          interestRate: (changes['interest_rate'] as num?)?.toDouble() ?? loan.interestRate,
          totalDue: (changes['total_due'] as num?)?.toDouble() ?? loan.totalDue,
          totalPaid: (changes['total_paid'] as num?)?.toDouble() ?? loan.totalPaid,
          installmentsTotal: (changes['installments_total'] as num?)?.toInt() ?? loan.installmentsTotal,
          installmentsPaid: (changes['installments_paid'] as num?)?.toInt() ?? loan.installmentsPaid,
          installmentAmount: (changes['installment_amount'] as num?)?.toDouble() ?? loan.installmentAmount,
          status: changes['status']?.toString() ?? loan.status,
          nextInstallmentDueAt: changes.containsKey('next_installment_due_at')
              ? DateTime.tryParse(changes['next_installment_due_at']?.toString() ?? '') ?? loan.nextInstallmentDueAt
              : loan.nextInstallmentDueAt,
          updatedAt: DateTime.now(),
        );
      }
      return loan;
    }).toList();

    state = AsyncData(updated);
  }

  void removeLoan(String loanId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((l) => l.id != loanId).toList());
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final playerLoansProvider =
    AsyncNotifierProvider<PlayerLoansNotifier, List<LoanModel>>(
  PlayerLoansNotifier.new,
);

class LoanLimitNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    try {
      final response = await supabase.rpc(
        'get_player_loan_limit',
        params: {'p_player_id': user.id},
      );
      return (response as num).toDouble();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Exception('Kredi limiti alınamadı: $e'), stackTrace);
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final loanLimitProvider =
    AsyncNotifierProvider<LoanLimitNotifier, double>(LoanLimitNotifier.new);

class PlayerDepositsNotifier extends AsyncNotifier<List<DepositModel>> {
  @override
  Future<List<DepositModel>> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await supabase
          .from('player_deposits')
          .select()
          .eq('player_id', user.id);

      return (response as List<dynamic>)
          .map((json) => DepositModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Exception('Mevduatlar alınamadı: $e'), stackTrace);
    }
  }

  void patchClaim(String depositId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((deposit) {
      if (deposit.id == depositId) {
        return deposit.copyWith(status: 'claimed');
      }
      return deposit;
    }).toList();

    state = AsyncData(updated);
  }

  void patchWithdrawEarly(String depositId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((deposit) {
      if (deposit.id == depositId) {
        return deposit.copyWith(status: 'withdrawn');
      }
      return deposit;
    }).toList();

    state = AsyncData(updated);
  }

  void insertDeposit(DepositModel deposit) {
    final current = state.value;
    if (current == null) {
      // Same invariant as loans: sparse inserts must not initialize a partial
      // multi-row list while its authoritative fetch is still loading.
      ref.invalidateSelf();
      return;
    }
    if (current.any((d) => d.id == deposit.id)) return;
    state = AsyncData([deposit, ...current]);
  }

  void patchDepositChanges(String depositId, Map<String, dynamic> changes) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((deposit) {
      if (deposit.id == depositId) {
        return deposit.copyWith(
          amount: (changes['amount'] as num?)?.toDouble() ?? deposit.amount,
          interestRate: (changes['interest_rate'] as num?)?.toDouble() ?? deposit.interestRate,
          expectedPayout: (changes['expected_payout'] as num?)?.toDouble() ?? deposit.expectedPayout,
          status: changes['status']?.toString() ?? deposit.status,
          lockedUntil: changes.containsKey('locked_until')
              ? DateTime.tryParse(changes['locked_until']?.toString() ?? '') ?? deposit.lockedUntil
              : deposit.lockedUntil,
          updatedAt: DateTime.now(),
        );
      }
      return deposit;
    }).toList();

    state = AsyncData(updated);
  }

  void removeDeposit(String depositId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((d) => d.id != depositId).toList());
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final playerDepositsProvider =
    AsyncNotifierProvider<PlayerDepositsNotifier, List<DepositModel>>(
  PlayerDepositsNotifier.new,
);

class MaxDepositLimitNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    try {
      final response = await supabase.rpc(
        'get_player_max_deposit_limit',
        params: {'p_player_id': user.id},
      );
      return (response as num).toDouble();
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(Exception('Mevduat limiti alınamadı: $e'), stackTrace);
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final maxDepositLimitProvider =
    AsyncNotifierProvider<MaxDepositLimitNotifier, double>(
  MaxDepositLimitNotifier.new,
);

class BankActionNotifier {
  final Ref _ref;
  BankActionNotifier(this._ref);

  Map<String, dynamic> _syncResponse(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    // `success` is a business outcome, not proof that no state changed. Some
    // failure envelopes (notably an overdue loan with insufficient cash) commit
    // a status transition such as active -> defaulted and include its patch.
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<Map<String, dynamic>> takeLoan(double amount, int installments) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'take_loan',
        params: {'p_amount': amount, 'p_installments': installments},
      );

      return _syncResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Kredi çekme işlemi başarısız: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> payLoanInstallment(String loanId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'pay_loan_installment',
        params: {'p_loan_id': loanId},
      );

      return _syncResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Taksit ödeme işlemi başarısız: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> payFullLoan(String loanId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'pay_full_loan',
        params: {'p_loan_id': loanId},
      );

      return _syncResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Kredi erken kapatma işlemi başarısız: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> createDeposit(double amount, int days) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'create_deposit',
        params: {'p_amount': amount, 'p_days': days},
      );

      // Creating a deposit moves principal from cash to deposit assets, so the
      // total-company-value based deposit limit does not change.
      return _syncResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Mevduat açma işlemi başarısız: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> claimDeposit(String depositId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'claim_deposit',
        params: {'p_deposit_id': depositId},
      );

      final result = _syncResponse(response);
      if (result['success'] == true) {
        // Interest changes total company value, therefore the limit can change.
        _ref.read(maxDepositLimitProvider.notifier).refresh();
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Mevduat çekme işlemi başarısız: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> withdrawDepositEarly(String depositId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'withdraw_deposit_early',
        params: {'p_deposit_id': depositId},
      );

      final result = _syncResponse(response);
      if (result['success'] == true) {
        // The early-withdrawal penalty reduces total company value.
        _ref.read(maxDepositLimitProvider.notifier).refresh();
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Erken çekim işlemi başarısız: ${e.toString()}',
      };
    }
  }
}

final bankActionProvider = Provider<BankActionNotifier>((ref) {
  return BankActionNotifier(ref);
});
