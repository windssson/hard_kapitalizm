import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

final argeProductsProvider =
    FutureProvider.autoDispose<List<ArgeProductModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final response = await supabase.rpc('get_arge_products_with_quality');

      return (response as List<dynamic>)
          .map((p) {
            final map = Map<String, dynamic>.from(p as Map);
            final quality =
                (map['current_quality_level'] as num?)?.toInt() ?? 1;
            return ArgeProductModel.fromJson(map, quality);
          })
          .toList();
    });

final activeArgeResearchesProvider =
    FutureProvider<List<ArgeResearchModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final response = await supabase.rpc(
        'get_active_arge_researches',
        params: {'p_player_id': user.id},
      );

      final list = response as List<dynamic>;
      return list
          .map((r) => ArgeResearchModel.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    });

final activeArgeResearchProvider =
    Provider<AsyncValue<ArgeResearchModel?>>((ref) {
      final researchesAsync = ref.watch(activeArgeResearchesProvider);
      return researchesAsync.whenData(
        (researches) => researches.isEmpty ? null : researches.first,
      );
    });

final playerArgeCenterProvider =
    FutureProvider.autoDispose<ArgeCenterModel?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase.rpc('get_player_arge_center');
      if (response == null) return null;

      return ArgeCenterModel.fromJson(response as Map<String, dynamic>);
    });

final playerArgeConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase.rpc(
        'get_player_building_constructions',
        params: {
          'p_building_kind': 'arge_center',
          'p_status': 'in_progress',
        },
      );

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;

      return rows.first as Map<String, dynamic>;
    });

final activeArgeCenterUpgradeProvider =
    FutureProvider.autoDispose.family<BuildingUpgradeModel?, String>((
      ref,
      centerId,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'arge_center',
          'p_entity_id': centerId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

class ArgeActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  ArgeActionNotifier(this._ref);

  Future<Map<String, dynamic>> startCenterConstruction({
    String name = 'AR-GE Merkezi',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'start_arge_center_construction',
        params: {
          'p_player_id': user.id,
          'p_name': name,
        },
      );
      _ref.invalidate(playerArgeCenterProvider);
      _ref.invalidate(playerArgeConstructionProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startResearch(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};
    try {
      final response = await _supabase.rpc(
        'start_arge_research',
        params: {'p_player_id': user.id, 'p_product_id': productId},
      );
      _ref.invalidate(activeArgeResearchesProvider);
      _ref.invalidate(argeProductsProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeResearch(String researchId) async {
    try {
      final response = await _supabase.rpc(
        'complete_arge_research',
        params: {'p_research_id': researchId},
      );
      _ref.invalidate(activeArgeResearchesProvider);
      _ref.invalidate(argeProductsProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishWithGold(String researchId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};
    try {
      final response = await _supabase.rpc(
        'finish_arge_with_gold',
        params: {'p_player_id': user.id, 'p_research_id': researchId},
      );
      _ref.invalidate(activeArgeResearchesProvider);
      _ref.invalidate(argeProductsProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(String constructionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'complete_building_construction',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      _ref.invalidate(playerArgeCenterProvider);
      _ref.invalidate(playerArgeConstructionProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'finish_construction_with_gold',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      _ref.invalidate(playerArgeCenterProvider);
      _ref.invalidate(playerArgeConstructionProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startCenterUpgrade(String centerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'start_building_upgrade',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'arge_center',
          'p_entity_id': centerId,
        },
      );
      _ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueBuildingUpgrades() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'complete_due_building_upgrades',
        params: {
          'p_limit': 100,
        },
      );
      _ref.invalidate(playerArgeCenterProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishCenterUpgradeWithGold(String upgradeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'finish_building_upgrade_with_gold',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
        },
      );
      _ref.invalidate(playerArgeCenterProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final argeActionProvider = Provider((ref) => ArgeActionNotifier(ref));
