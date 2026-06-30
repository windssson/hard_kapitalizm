import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

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
        _ref.invalidate(playerProvider);
        _ref.invalidate(taxDebtProvider);
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
