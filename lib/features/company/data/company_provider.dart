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

final activeMarketingCampaignsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      try {
        final response = await supabase.rpc('get_active_marketing_campaigns');

        final rows = response as List<dynamic>? ?? const [];
        return rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } catch (e) {
        return const [];
      }
    });

class CompanyActionNotifier {
  CompanyActionNotifier(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createBrandCompany({
    required String brandName,
    required String logoId,
    required String themeColor,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'create_brand_company',
        params: {
          'p_brand_name': brandName,
          'p_logo_id': logoId,
          'p_theme_color': themeColor,
        },
      );
      _ref.invalidate(playerBrandCompanyProvider);
      _ref.invalidate(playerBrandCompanyProductsProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBrandCompany({
    required String logoId,
    required String themeColor,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'update_brand_company',
        params: {
          'p_logo_id': logoId,
          'p_theme_color': themeColor,
        },
      );
      _ref.invalidate(playerBrandCompanyProvider);
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

  Future<Map<String, dynamic>> setBrandProductWatermark({
    required String productId,
    String? watermarkAssetId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_brand_company_product_watermark',
        params: {
          'p_product_id': productId,
          'p_watermark_asset_id': watermarkAssetId,
        },
      );
      _ref.invalidate(playerBrandCompanyProductsProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startMarketingCampaign({
    required String campaignType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_marketing_campaign',
        params: {'p_campaign_type': campaignType},
      );
      _ref.invalidate(playerBrandCompanyProvider);
      _ref.invalidate(activeMarketingCampaignsProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final companyActionProvider =
    Provider<CompanyActionNotifier>((ref) => CompanyActionNotifier(ref));
