import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

final activeArgeResearchProvider =
    StreamProvider.autoDispose<ArgeResearchModel?>((ref) {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const Stream.empty();

      return supabase
          .from('arge_researches')
          .stream(primaryKey: ['id'])
          .eq('player_id', user.id)
          .map((rows) {
            final inProgress = rows.where((r) => r['status'] == 'in_progress');
            if (inProgress.isEmpty) return null;
            return ArgeResearchModel.fromJson(
              Map<String, dynamic>.from(inProgress.first),
            );
          });
    });

class ArgeActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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
}

final argeActionProvider = Provider((ref) => ArgeActionNotifier());
