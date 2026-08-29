import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
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

  Future<Map<String, dynamic>> takeLoan(double amount, int installments) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'take_loan',
        params: {'p_amount': amount, 'p_installments': installments},
      );

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerLoansProvider.notifier).refresh();
        _ref.read(loanLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
      }
      return result;
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

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerLoansProvider.notifier).patchPayInstallment(loanId);
        _ref.read(playerLoansProvider.notifier).refresh();
        _ref.read(loanLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
      }
      return result;
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

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerLoansProvider.notifier).patchPayFull(loanId);
        _ref.read(playerLoansProvider.notifier).refresh();
        _ref.read(loanLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
      }
      return result;
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

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerDepositsProvider.notifier).refresh();
        _ref.read(maxDepositLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
      }
      return result;
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

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerDepositsProvider.notifier).patchClaim(depositId);
        _ref.read(playerDepositsProvider.notifier).refresh();
        _ref.read(maxDepositLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
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

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.read(playerDepositsProvider.notifier).patchWithdrawEarly(depositId);
        _ref.read(playerDepositsProvider.notifier).refresh();
        _ref.read(maxDepositLimitProvider.notifier).refresh();
        _ref.invalidate(playerProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
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
