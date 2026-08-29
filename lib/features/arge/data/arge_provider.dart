import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_center_model.dart';
import 'package:hard_kapitalizm/features/arge/models/arge_product_model.dart';

Future<List<ArgeProductModel>> _fetchArgeProducts() async {
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
}

class ArgeProductsNotifier extends AsyncNotifier<List<ArgeProductModel>> {
  @override
  Future<List<ArgeProductModel>> build() => _fetchArgeProducts();

  Future<List<ArgeProductModel>> refresh() async {
    final list = await _fetchArgeProducts();
    state = AsyncData(list);
    return list;
  }

  void patchProductQuality(String productId, int newQualityLevel) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((prod) {
      if (prod.id == productId) {
        return prod.copyWith(currentQualityLevel: newQualityLevel);
      }
      return prod;
    }).toList();
    state = AsyncData(updated);
  }
}

final argeProductsProvider =
    AsyncNotifierProvider<ArgeProductsNotifier, List<ArgeProductModel>>(
      ArgeProductsNotifier.new,
    );

Future<List<ArgeResearchModel>> _fetchActiveArgeResearches() async {
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
}

class ActiveArgeResearchesNotifier
    extends AsyncNotifier<List<ArgeResearchModel>> {
  @override
  Future<List<ArgeResearchModel>> build() => _fetchActiveArgeResearches();

  Future<List<ArgeResearchModel>> refresh() async {
    final list = await _fetchActiveArgeResearches();
    state = AsyncData(list);
    return list;
  }

  void addResearch(ArgeResearchModel research) {
    final current = state.value ?? [];
    state = AsyncData([...current, research]);
  }

  void removeResearch(String researchId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != researchId).toList());
  }

  void clear() {
    state = const AsyncData([]);
  }
}

final activeArgeResearchesProvider = AsyncNotifierProvider<
    ActiveArgeResearchesNotifier,
    List<ArgeResearchModel>
>(ActiveArgeResearchesNotifier.new);

final activeArgeResearchProvider =
    Provider<AsyncValue<ArgeResearchModel?>>((ref) {
      final researchesAsync = ref.watch(activeArgeResearchesProvider);
      return researchesAsync.whenData(
        (researches) => researches.isEmpty ? null : researches.first,
      );
    });

Future<ArgeCenterModel?> _fetchPlayerArgeCenter() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final response = await supabase.rpc('get_player_arge_center');
  if (response == null) return null;

  return ArgeCenterModel.fromJson(Map<String, dynamic>.from(response as Map));
}

class PlayerArgeCenterNotifier extends AsyncNotifier<ArgeCenterModel?> {
  @override
  Future<ArgeCenterModel?> build() => _fetchPlayerArgeCenter();

  Future<ArgeCenterModel?> refresh() async {
    final center = await _fetchPlayerArgeCenter();
    state = AsyncData(center);
    return center;
  }

  void setCenter(ArgeCenterModel? center) {
    state = AsyncData(center);
  }

  void patchLevel(int newLevel) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(level: newLevel));
  }
}

final playerArgeCenterProvider =
    AsyncNotifierProvider<PlayerArgeCenterNotifier, ArgeCenterModel?>(
      PlayerArgeCenterNotifier.new,
    );

Future<Map<String, dynamic>?> _fetchPlayerArgeConstruction() async {
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

  final rows = response as List<dynamic>? ?? const [];
  if (rows.isEmpty) return null;

  return Map<String, dynamic>.from(rows.first as Map);
}

class PlayerArgeConstructionNotifier
    extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() => _fetchPlayerArgeConstruction();

  Future<Map<String, dynamic>?> refresh() async {
    final data = await _fetchPlayerArgeConstruction();
    state = AsyncData(data);
    return data;
  }

  void setConstruction(Map<String, dynamic>? data) {
    state = AsyncData(data);
  }

  void patchFinishAt(DateTime newFinishAt) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData({
      ...current,
      'finish_at': newFinishAt.toIso8601String(),
    });
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final playerArgeConstructionProvider = AsyncNotifierProvider<
    PlayerArgeConstructionNotifier,
    Map<String, dynamic>?
>(PlayerArgeConstructionNotifier.new);

Future<BuildingUpgradeModel?> _fetchActiveArgeCenterUpgrade(
    String centerId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_active_building_upgrade',
    params: {
      'p_building_kind': 'arge_center',
      'p_entity_id': centerId,
    },
  );

  if (response == null) return null;

  return BuildingUpgradeModel.fromJsonNullable(
    Map<String, dynamic>.from(response as Map),
  );
}

class ActiveArgeCenterUpgradeNotifier
    extends AsyncNotifier<BuildingUpgradeModel?> {
  ActiveArgeCenterUpgradeNotifier(this._centerId);

  final String _centerId;

  @override
  Future<BuildingUpgradeModel?> build() =>
      _fetchActiveArgeCenterUpgrade(_centerId);

  Future<BuildingUpgradeModel?> refresh() async {
    final data = await _fetchActiveArgeCenterUpgrade(_centerId);
    state = AsyncData(data);
    return data;
  }

  void setUpgrade(BuildingUpgradeModel? upgrade) {
    state = AsyncData(upgrade);
  }

  void reduceTime(Duration duration) {
    final current = state.value;
    if (current == null) return;
    final reducedFinishAt = current.finishAt.subtract(duration);
    state = AsyncData(current.copyWith(finishAt: reducedFinishAt));
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final activeArgeCenterUpgradeProvider = AsyncNotifierProvider.family<
    ActiveArgeCenterUpgradeNotifier,
    BuildingUpgradeModel?,
    String
>(ActiveArgeCenterUpgradeNotifier.new);

class ArgeActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  ArgeActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<Map<String, dynamic>> startCenterConstruction({
    String name = 'AR-GE Merkezi',
    bool syncProviders = true,
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
      if (syncProviders) {
        _ref.invalidate(playerArgeCenterProvider);
        _ref.invalidate(playerArgeConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startResearch(
    String productId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};
    try {
      final response = await _supabase.rpc(
        'start_arge_research',
        params: {'p_player_id': user.id, 'p_product_id': productId},
      );
      if (syncProviders) {
        _ref.invalidate(activeArgeResearchesProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeResearch(
    String researchId, {
    bool syncProviders = true,
  }) async {
    try {
      final response = await _supabase.rpc(
        'complete_arge_research',
        params: {'p_research_id': researchId},
      );
      if (syncProviders) {
        _ref.invalidate(activeArgeResearchesProvider);
        _ref.invalidate(argeProductsProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishWithGold(
    String researchId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};
    try {
      final response = await _supabase.rpc(
        'finish_arge_with_gold',
        params: {'p_player_id': user.id, 'p_research_id': researchId},
      );
      if (syncProviders) {
        _ref.invalidate(activeArgeResearchesProvider);
        _ref.invalidate(argeProductsProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId, {
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(playerArgeCenterProvider);
        _ref.invalidate(playerArgeConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId, {
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(playerArgeCenterProvider);
        _ref.invalidate(playerArgeConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceConstructionTimeWithAd(
    String constructionId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'reduce_construction_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      if (syncProviders) {
        _ref.invalidate(playerArgeConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startCenterUpgrade(
    String centerId, {
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueBuildingUpgrades() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      await tryCompleteDueBuildingUpgrades(_supabase);
      _ref.invalidate(playerArgeCenterProvider);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishCenterUpgradeWithGold(
    String upgradeId, {
    String? centerId,
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(playerArgeCenterProvider);
        if (centerId != null) {
          _ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
        }
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceCenterUpgradeTimeWithAd(
    String upgradeId, {
    String? centerId,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'reduce_building_upgrade_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
        },
      );
      if (syncProviders && centerId != null) {
        _ref.invalidate(activeArgeCenterUpgradeProvider(centerId));
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final argeActionProvider = Provider((ref) => ArgeActionNotifier(ref));
