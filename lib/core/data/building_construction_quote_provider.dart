import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/models/building_construction_quote_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef BuildingConstructionQuoteRequest = ({
  String cityId,
  String buildingKind,
  String? buildingTypeId,
});

final buildingConstructionQuoteProvider = FutureProvider.autoDispose
    .family<BuildingConstructionQuoteModel, BuildingConstructionQuoteRequest>((
      ref,
      request,
    ) async {
      final response = await Supabase.instance.client.rpc(
        'get_building_construction_quote',
        params: {
          'p_city_id': request.cityId,
          'p_building_kind': request.buildingKind,
          'p_type_id': request.buildingTypeId,
        },
      );

      final result = Map<String, dynamic>.from(response as Map);
      ref.read(mutationSyncServiceProvider).applyRaw(result);
      return BuildingConstructionQuoteModel.fromJson(result);
    });
