import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

final playerBrandCompanyProvider =
    FutureProvider.autoDispose<BrandCompanyModel?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase.rpc('get_player_brand_company');
      if (response == null) return null;
      return BrandCompanyModel.fromJson(response as Map<String, dynamic>);
    });

final playerBrandCompanyProductsProvider =
    FutureProvider.autoDispose<List<BrandCompanyProductModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      final response = await supabase.rpc('get_player_brand_company_products');
      final rows = response as List<dynamic>? ?? const [];
      return rows
          .map(
            (row) => BrandCompanyProductModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    });

class CompanyActionNotifier {
  CompanyActionNotifier(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createBrandCompany({
    required String brandName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'create_brand_company',
        params: {'p_brand_name': brandName},
      );
      _ref.invalidate(playerBrandCompanyProvider);
      _ref.invalidate(playerBrandCompanyProductsProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> patentBrandProduct({
    required String productId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'patent_brand_company_product',
        params: {'p_product_id': productId},
      );
      _ref.invalidate(playerBrandCompanyProvider);
      _ref.invalidate(playerBrandCompanyProductsProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final companyActionProvider =
    Provider<CompanyActionNotifier>((ref) => CompanyActionNotifier(ref));
