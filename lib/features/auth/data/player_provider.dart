import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';

final playerStreamProvider = StreamProvider<PlayerModel?>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return const Stream.empty();

  return supabase
      .from('players')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((event) => event.isNotEmpty ? PlayerModel.fromJson(event.first) : null);
});
