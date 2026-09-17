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

  // Development-only quick-login credentials.
  // Keep the real values in the local .env file; never commit them to GitHub.
  static String get devAdminEmail =>
      dotenv.env['DEV_ADMIN_EMAIL'] ?? '';

  static String get devAdminPassword =>
      dotenv.env['DEV_ADMIN_PASSWORD'] ?? '';

  static String get devOwnerEmail =>
      dotenv.env['DEV_OWNER_EMAIL'] ?? '';

  static String get devOwnerPassword =>
      dotenv.env['DEV_OWNER_PASSWORD'] ?? '';

  static String get devUserEmail =>
      dotenv.env['DEV_USER_EMAIL'] ?? '';

  static String get devUserPassword =>
      dotenv.env['DEV_USER_PASSWORD'] ?? '';

  static String get devDeveloperEmail =>
      dotenv.env['DEV_DEVELOPER_EMAIL'] ?? '';

  static String get devDeveloperPassword =>
      dotenv.env['DEV_DEVELOPER_PASSWORD'] ?? '';
}
