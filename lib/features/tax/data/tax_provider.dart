import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerTaxModel {
  final double taxDebt;
  final double taxLimit;
  final bool isBlocked;

  const PlayerTaxModel({
    required this.taxDebt,
    required this.taxLimit,
    required this.isBlocked,
  });

  PlayerTaxModel copyWith({
    double? taxDebt,
    double? taxLimit,
    bool? isBlocked,
  }) {
    return PlayerTaxModel(
      taxDebt: taxDebt ?? this.taxDebt,
      taxLimit: taxLimit ?? this.taxLimit,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  factory PlayerTaxModel.fromJson(Map<String, dynamic> json) {
    return PlayerTaxModel(
      taxDebt: (json['tax_debt'] as num?)?.toDouble() ?? 0.0,
      taxLimit: (json['tax_limit'] as num?)?.toDouble() ?? 0.0,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }
}

class TaxDebtNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return 0.0;

    try {
      final response = await supabase.rpc('get_player_tax_debt');
      if (response == null) return 0.0;
      return (response as num).toDouble();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Vergi borcu alınamadı: $error'),
        stackTrace,
      );
    }
  }

  void patchPayment(double amount) {
    final current = state.value;
    if (current == null) return;
    final newDebt = (current - amount).clamp(0.0, double.infinity);
    state = AsyncData(newDebt);
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

final taxDebtProvider =
    AsyncNotifierProvider<TaxDebtNotifier, double>(TaxDebtNotifier.new);

class PlayerTaxNotifier extends AsyncNotifier<PlayerTaxModel> {
  @override
  Future<PlayerTaxModel> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const PlayerTaxModel(taxDebt: 0, taxLimit: 0, isBlocked: false);
    }

    try {
      final response = await supabase.rpc('get_player_tax_status');
      if (response == null) {
        return const PlayerTaxModel(taxDebt: 0, taxLimit: 0, isBlocked: false);
      }
      return PlayerTaxModel.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        Exception('Vergi durumu alınamadı: $error'),
        stackTrace,
      );
    }
  }

  void patchPayment(double amount) {
    final current = state.value;
    if (current == null) return;
    final newDebt = (current.taxDebt - amount).clamp(0.0, double.infinity);
    final isBlocked = newDebt > current.taxLimit;
    state = AsyncData(current.copyWith(taxDebt: newDebt, isBlocked: isBlocked));
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

final playerTaxProvider =
    AsyncNotifierProvider<PlayerTaxNotifier, PlayerTaxModel>(
  PlayerTaxNotifier.new,
);

class TaxActionNotifier {
  final Ref _ref;
  TaxActionNotifier(this._ref);

  Future<Map<String, dynamic>> payTax(double amount) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'pay_tax_debt',
        params: {'p_amount': amount},
      );

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        final currentTax = _ref.read(playerTaxProvider).value;
        final payAmount = amount == -1 ? (currentTax?.taxDebt ?? 0.0) : amount;
        _ref.read(taxDebtProvider.notifier).patchPayment(payAmount);
        _ref.read(playerTaxProvider.notifier).patchPayment(payAmount);
        _ref.read(mutationSyncServiceProvider).applyRaw(result);
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Vergi ödeme işlemi başarısız: ${e.toString()}',
      };
    }
  }
}

final taxActionProvider = Provider<TaxActionNotifier>((ref) {
  return TaxActionNotifier(ref);
});
