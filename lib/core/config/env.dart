import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get appName =>
      dotenv.env['APP_NAME'] ?? 'HALAL Food';

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? '';

  static String get mapsApiKey =>
      dotenv.env['MAPS_API_KEY'] ?? '';

  static String get authApiKey =>
      dotenv.env['AUTH_API_KEY'] ?? '';

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
}