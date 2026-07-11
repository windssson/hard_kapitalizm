import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_quote_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef BuildingUpgradeQuoteRequest = ({String buildingKind, String entityId});

final buildingUpgradeQuoteProvider = FutureProvider.autoDispose
    .family<BuildingUpgradeQuoteModel, BuildingUpgradeQuoteRequest>((
      ref,
      request,
    ) async {
      final response = await Supabase.instance.client.rpc(
        'get_building_upgrade_quote',
        params: {
          'p_building_kind': request.buildingKind,
          'p_entity_id': request.entityId,
        },
      );

      return BuildingUpgradeQuoteModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });
