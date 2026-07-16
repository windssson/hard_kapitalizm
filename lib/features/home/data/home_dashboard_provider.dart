import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/home/models/home_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final homeDashboardProvider = FutureProvider<HomeDashboardModel>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_homepage_dashboard_v2');

  return HomeDashboardModel.fromJson(
    response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map),
  );
});
