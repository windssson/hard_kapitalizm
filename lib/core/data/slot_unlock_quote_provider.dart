import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/slot_unlock_quote_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SlotUnlockQuoteRequest = ({String buildingKind, String entityId});

final slotUnlockQuoteProvider = FutureProvider.autoDispose
    .family<SlotUnlockQuoteModel, SlotUnlockQuoteRequest>((ref, request) async {
      final response = await Supabase.instance.client.rpc(
        'get_slot_unlock_quote',
        params: {
          'p_building_kind': request.buildingKind,
          'p_entity_id': request.entityId,
        },
      );

      return SlotUnlockQuoteModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });
