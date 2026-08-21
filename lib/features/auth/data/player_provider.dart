import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/mutation/player_changes.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

/// AsyncNotifier tabanlı player provider.
/// RPC sonuçlarından gelen değişiklikleri invalidate yerine patch ederek uygular.
class PlayerNotifier extends AsyncNotifier<PlayerModel?> {
  @override
  Future<PlayerModel?> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase.rpc(
      'get_player_profile',
      params: {'p_player_id': user.id},
    );

    if (response == null) return null;
    return PlayerModel.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // ─── Tam güncelleme ───────────────────────────────────────────────────────

  /// State'i verilen PlayerModel ile tamamen değiştirir.
  void replacePlayer(PlayerModel player) {
    state = AsyncData(player);
  }

  /// PlayerChanges modelinden mevcut state üzerine patch uygular.
  /// fullPlayer varsa onu kullanır, yoksa sadece değişen alanları uygular.
  void applyChanges(PlayerChanges changes) {
    final current = state.value;
    if (changes.fullPlayer != null) {
      state = AsyncData(changes.fullPlayer);
      return;
    }
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        cash: changes.cash ?? current.cash,
        gold: changes.gold ?? current.gold,
        level: changes.level ?? current.level,
        experience: changes.experience ?? current.experience,
        avatarId: changes.avatarId ?? current.avatarId,
        companyName: changes.companyName ?? current.companyName,
      ),
    );
  }

  // ─── Alan bazlı patch ─────────────────────────────────────────────────────

  void patchCash(double cash) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(cash: cash));
  }

  void patchGold(double gold) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(gold: gold));
  }

  void patchLevel(int level) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(level: level));
  }

  void patchExperience(int experience) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(experience: experience));
  }

  void patchAvatar(String avatarId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(avatarId: avatarId));
  }

  void patchCompanyName(String companyName) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(companyName: companyName));
  }

  void patchHeadquartersCity({
    required String cityId,
    required String cityName,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        headquartersCityId: cityId,
        headquartersCityName: cityName,
      ),
    );
  }

  // ─── Aksiyonlar ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> setHeadquartersCity(String cityId, {String? cityName}) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'set_player_headquarters_city',
        params: {'p_city_id': cityId},
      );
      if (response != null && response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['success'] == true) {
          final resolvedName = map['headquarters_city_name']?.toString() ?? cityName ?? '';
          patchHeadquartersCity(
            cityId: cityId,
            cityName: resolvedName,
          );
        }
        return map;
      }
      return {'success': false, 'message': 'Bilinmeyen yanıt.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> setPlayerAvatar(String avatarId) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.rpc(
      'set_player_avatar',
      params: {'p_avatar_id': avatarId},
    );

    // RPC başarılı olduktan sonra patch uygula
    if (response != null) {
      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final changes = PlayerChanges.tryExtract(json);
      if (changes != null) {
        applyChanges(changes);
        return;
      }
    }
    // Fallback: response yeterli veri içermiyorsa sadece avatarı patch et
    patchAvatar(avatarId);
  }

  Future<void> updateCompanyName(String newName) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase.rpc(
      'update_company_name',
      params: {'p_company_name': newName},
    );

    if (response != null) {
      final json = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final changes = PlayerChanges.tryExtract(json);
      if (changes != null) {
        applyChanges(changes);
        return;
      }
    }
    patchCompanyName(newName);
  }

  /// Zorla yenile (örn: login sonrası veya kritik hata sonrası)
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final playerProvider = AsyncNotifierProvider<PlayerNotifier, PlayerModel?>(
  PlayerNotifier.new,
);

// ─── Eski PlayerActionNotifier — geriye dönük uyumluluk için tutulur ─────────
// Yeni kod PlayerNotifier üzerindeki metotları doğrudan kullanmalı.
// ignore: deprecated_member_use_from_same_package
@Deprecated('Use ref.read(playerProvider.notifier) directly')
class PlayerActionNotifier {
  final Ref _ref;
  PlayerActionNotifier(this._ref);

  Future<void> setPlayerAvatar(String avatarId) async {
    await _ref.read(playerProvider.notifier).setPlayerAvatar(avatarId);
  }

  Future<void> updateCompanyName(String newName) async {
    await _ref.read(playerProvider.notifier).updateCompanyName(newName);
  }
}

// ignore: deprecated_member_use_from_same_package
@Deprecated('Use ref.read(playerProvider.notifier) directly')
final playerActionProvider = Provider<PlayerActionNotifier>((ref) {
  return PlayerActionNotifier(ref);
});

final publicProfileProvider =
    FutureProvider.family<PlayerModel?, String>((ref, playerId) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_player_profile',
        params: {'p_player_id': playerId},
      );

      if (response == null) return null;
      return PlayerModel.fromJson(response as Map<String, dynamic>);
    });
