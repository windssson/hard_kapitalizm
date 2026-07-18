import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerTaxModel {
  final double taxDebt;
  final double taxLimit;
  final bool isBlocked;

  PlayerTaxModel({
    required this.taxDebt,
    required this.taxLimit,
    required this.isBlocked,
  });

  factory PlayerTaxModel.fromJson(Map<String, dynamic> json) {
    return PlayerTaxModel(
      taxDebt: (json['tax_debt'] as num?)?.toDouble() ?? 0.0,
      taxLimit: (json['tax_limit'] as num?)?.toDouble() ?? 0.0,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }
}

final taxDebtProvider = FutureProvider<double>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return 0.0;

  try {
    final response = await supabase.rpc('get_player_tax_debt');
    if (response == null) return 0.0;
    return (response as num).toDouble();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      Exception('Vergi borcu alinamadi: $error'),
      stackTrace,
    );
  }
});

final playerTaxProvider = FutureProvider<PlayerTaxModel>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    return PlayerTaxModel(taxDebt: 0, taxLimit: 0, isBlocked: false);
  }

  try {
    final response = await supabase.rpc('get_player_tax_status');
    if (response == null) {
      return PlayerTaxModel(taxDebt: 0, taxLimit: 0, isBlocked: false);
    }
    return PlayerTaxModel.fromJson(Map<String, dynamic>.from(response as Map));
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      Exception('Vergi durumu alinamadi: $error'),
      stackTrace,
    );
  }
});

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
        _ref.invalidate(taxDebtProvider);
        _ref.invalidate(playerTaxProvider);
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Vergi odeme islemi basarisiz: ${e.toString()}',
      };
    }
  }
}

final taxActionProvider = Provider<TaxActionNotifier>((ref) {
  return TaxActionNotifier(ref);
});


