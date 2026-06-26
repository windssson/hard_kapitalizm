import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static const String authCallbackScheme = 'com.winds.hardkapitalizm';
  static const String authCallbackHost = 'login-callback';
  static const String authCallbackUrl =
      '$authCallbackScheme://$authCallbackHost/';
}
