import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';

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
    StreamProvider.autoDispose<List<ArgeResearchModel>>((ref) {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const Stream.empty();

      return supabase
          .from('arge_researches')
          .stream(primaryKey: ['id'])
          .eq('player_id', user.id)
          .map((rows) {
            final inProgress = rows
                .where((r) => r['status'] == 'in_progress')
                .map((r) => Map<String, dynamic>.from(r))
                .toList()
              ..sort((a, b) {
                final aStartedAt =
                    DateTime.tryParse(a['started_at']?.toString() ?? '');
                final bStartedAt =
                    DateTime.tryParse(b['started_at']?.toString() ?? '');
                if (aStartedAt == null && bStartedAt == null) return 0;
                if (aStartedAt == null) return 1;
                if (bStartedAt == null) return -1;
                return bStartedAt.compareTo(aStartedAt);
              });

            return inProgress.map(ArgeResearchModel.fromJson).toList();
          });
    });

final activeArgeResearchProvider =
    Provider.autoDispose<AsyncValue<ArgeResearchModel?>>((ref) {
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
  final SupabaseClient _supabase = Supabase.instance.client;

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
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final argeActionProvider = Provider((ref) => ArgeActionNotifier());
