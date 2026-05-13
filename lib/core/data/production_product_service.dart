import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<SelectableProductionProductModel>> fetchSelectableProductionProducts({
  required SupabaseClient supabase,
  required String ownerKind,
  required String typeId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Oturum acilmamis.');
  }

  final response = await supabase.rpc(
    'get_producible_products_for_owner_type',
    params: {
      'p_player_id': user.id,
      'p_owner_kind': ownerKind,
      'p_type_id': typeId,
    },
  );

  return (response as List<dynamic>)
      .map(
        (row) => SelectableProductionProductModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
      )
      .toList();
}
