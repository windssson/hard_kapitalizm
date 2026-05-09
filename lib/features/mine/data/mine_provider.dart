import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

// Maden Listesi Provider (Stream)
final mineListStreamProvider = StreamProvider.autoDispose<List<MineModel>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return const Stream.empty();

  return supabase
      .from('mines')
      .stream(primaryKey: ['id'])
      .eq('player_id', user.id)
      .map((event) => event.map((e) => MineModel.fromJson(e)).toList());
});

// Maden Tipleri Provider
final mineTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('mine_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

// Maden Aksiyonları
class MineActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createMine({
    required String cityId,
    required String typeId,
    required String name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

    try {
      final response = await _supabase.rpc(
        'start_building_construction',
        params: {
          'p_player_id': user.id,
          'p_city_id': cityId,
          'p_building_kind': 'mine',
          'p_type_id': typeId,
          'p_name': name,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final mineActionProvider = Provider((ref) => MineActionNotifier());
