import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/bank/models/loan_model.dart';
import 'package:hard_kapitalizm/features/bank/models/deposit_model.dart';

final playerLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
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
    Error.throwWithStackTrace(Exception('Krediler alinamadi: $e'), stackTrace);
  }
});

final playerDepositsProvider = FutureProvider<List<DepositModel>>((ref) async {
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
    Error.throwWithStackTrace(Exception('Mevduatlar alinamadi: $e'), stackTrace);
  }
});

final loanLimitProvider = FutureProvider<double>((ref) async {
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
    Error.throwWithStackTrace(Exception('Kredi limiti alinamadi: $e'), stackTrace);
  }
});

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
        _ref.invalidate(playerLoansProvider);
        _ref.invalidate(loanLimitProvider);
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
        _ref.invalidate(playerLoansProvider);
        _ref.invalidate(loanLimitProvider);
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

  Future<Map<String, dynamic>> createDeposit(double amount, int days) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'create_deposit',
        params: {'p_amount': amount, 'p_days': days},
      );

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        _ref.invalidate(playerDepositsProvider);
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
        _ref.invalidate(playerDepositsProvider);
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
        _ref.invalidate(playerDepositsProvider);
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


