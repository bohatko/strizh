import 'package:app_template/env/env.dart' as env;

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  static const String _envKey = 'APP_ENV';
  static const String _supabaseUrlKey = 'SUPABASE_URL';
  static const String _supabaseAnonKey = 'SUPABASE_ANON_KEY';

  /// Supabase URL.
  ///
  /// Priority:
  /// 1) --dart-define=SUPABASE_URL
  /// 2) lib/env/env.dart (env.supabaseUrl)
  static const String supabaseUrl = String.fromEnvironment(
    _supabaseUrlKey,
    defaultValue: env.supabaseUrl,
  );

  /// Supabase anon key.
  ///
  /// Priority:
  /// 1) --dart-define=SUPABASE_ANON_KEY
  /// 2) lib/env/env.dart (env.supabaseAnonKey)
  static const String supabaseAnonKey = String.fromEnvironment(
    _supabaseAnonKey,
    defaultValue: env.supabaseAnonKey,
  );

  /// Raw environment name from dart-define, defaults to "dev".
  static const String _rawEnv = String.fromEnvironment(
    _envKey,
    defaultValue: 'dev',
  );

  static AppEnvironment get environment {
    switch (_rawEnv.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isProd => environment == AppEnvironment.prod;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isDev => environment == AppEnvironment.dev;
}

