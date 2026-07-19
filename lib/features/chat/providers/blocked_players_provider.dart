import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedPlayersNotifier extends Notifier<List<String>> {
  static const _kBlockedPlayersKey = 'blocked_players_list';

  @override
  List<String> build() {
    final list = <String>[];
    SharedPreferences.getInstance().then((prefs) {
      final loaded = prefs.getStringList(_kBlockedPlayersKey) ?? [];
      state = loaded;
    });
    return list;
  }

  Future<void> blockPlayer(String playerId) async {
    if (state.contains(playerId)) return;
    final updated = [...state, playerId];
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBlockedPlayersKey, updated);
  }

  Future<void> unblockPlayer(String playerId) async {
    if (!state.contains(playerId)) return;
    final updated = state.where((id) => id != playerId).toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBlockedPlayersKey, updated);
  }
}

final blockedPlayersProvider = NotifierProvider<BlockedPlayersNotifier, List<String>>(
  BlockedPlayersNotifier.new,
);
