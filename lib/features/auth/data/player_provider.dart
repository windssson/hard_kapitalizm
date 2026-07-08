import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

final playerProvider = FutureProvider<PlayerModel?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_profile',
    params: {'p_player_id': user.id},
  );

  if (response == null) return null;
  return PlayerModel.fromJson(Map<String, dynamic>.from(response as Map));
});

class PlayerActionNotifier {
  final Ref _ref;
  PlayerActionNotifier(this._ref);

  Future<void> setPlayerAvatar(String avatarId) async {
    final supabase = Supabase.instance.client;
    await supabase.rpc(
      'set_player_avatar',
      params: {'p_avatar_id': avatarId},
    );
    _ref.invalidate(playerProvider);
  }
}

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
