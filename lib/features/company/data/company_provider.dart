import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';

class PlayerBrandCompanyNotifier extends AsyncNotifier<BrandCompanyModel?> {
  @override
  Future<BrandCompanyModel?> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase.rpc('get_player_brand_company');
    if (response == null) return null;
    return BrandCompanyModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void patchDesign({required String logoId, required String themeColor}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(logoId: logoId, themeColor: themeColor));
  }
}

final playerBrandCompanyProvider =
    AsyncNotifierProvider<PlayerBrandCompanyNotifier, BrandCompanyModel?>(
  PlayerBrandCompanyNotifier.new,
);

class PlayerBrandCompanyProductsNotifier
    extends AsyncNotifier<List<BrandCompanyProductModel>> {
  @override
  Future<List<BrandCompanyProductModel>> build() async {
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
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void patchProductPatented(String productId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((item) {
      if (item.productId == productId) {
        return item.copyWith(isBranded: true, brandedAt: DateTime.now());
      }
      return item;
    }).toList();

    state = AsyncData(updated);
  }

  void patchProductWatermark(String productId, String? watermarkAssetId) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((item) {
      if (item.productId == productId) {
        return item.copyWith(watermarkAssetId: watermarkAssetId);
      }
      return item;
    }).toList();

    state = AsyncData(updated);
  }
}

final playerBrandCompanyProductsProvider = AsyncNotifierProvider<
    PlayerBrandCompanyProductsNotifier, List<BrandCompanyProductModel>>(
  PlayerBrandCompanyProductsNotifier.new,
);

class ActiveMarketingCampaignsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
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

final activeMarketingCampaignsProvider = AsyncNotifierProvider<
    ActiveMarketingCampaignsNotifier, List<Map<String, dynamic>>>(
  ActiveMarketingCampaignsNotifier.new,
);

class CompanyActionNotifier {
  CompanyActionNotifier(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  String _cleanErrorMessage(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length);
    }
    return str;
  }

  Future<Map<String, dynamic>> createBrandCompany({
    required String brandName,
    required String logoId,
    required String themeColor,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
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
      final result = Map<String, dynamic>.from(response as Map);
      _ref.read(playerBrandCompanyProvider.notifier).refresh();
      _ref.read(playerBrandCompanyProductsProvider.notifier).refresh();
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateBrandCompany({
    required String logoId,
    required String themeColor,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    try {
      final response = await _supabase.rpc(
        'update_brand_company',
        params: {
          'p_logo_id': logoId,
          'p_theme_color': themeColor,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      _ref.read(playerBrandCompanyProvider.notifier).patchDesign(
            logoId: logoId,
            themeColor: themeColor,
          );
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> patentBrandProduct({
    required String productId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    try {
      final response = await _supabase.rpc(
        'patent_brand_company_product',
        params: {'p_product_id': productId},
      );
      final result = Map<String, dynamic>.from(response as Map);
      _ref
          .read(playerBrandCompanyProductsProvider.notifier)
          .patchProductPatented(productId);
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> setBrandProductWatermark({
    required String productId,
    String? watermarkAssetId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_brand_company_product_watermark',
        params: {
          'p_product_id': productId,
          'p_watermark_asset_id': watermarkAssetId,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      _ref
          .read(playerBrandCompanyProductsProvider.notifier)
          .patchProductWatermark(productId, watermarkAssetId);
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> startMarketingCampaign({
    required String campaignType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_marketing_campaign',
        params: {'p_campaign_type': campaignType},
      );
      final result = Map<String, dynamic>.from(response as Map);
      _ref.read(playerBrandCompanyProvider.notifier).refresh();
      _ref.read(activeMarketingCampaignsProvider.notifier).refresh();
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanErrorMessage(e)};
    }
  }
}

final companyActionProvider =
    Provider<CompanyActionNotifier>((ref) => CompanyActionNotifier(ref));
