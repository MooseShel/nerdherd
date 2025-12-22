import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration loaded from environment variables
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// Load configuration from .env file
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  /// Supabase project URL
  String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL not found in .env file');
    }
    return url;
  }

  /// Supabase anonymous key
  String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }
    return key;
  }

  /// Check if running in debug mode
  bool get isDebug {
    return dotenv.env['DEBUG']?.toLowerCase() == 'true';
  }

  /// Get environment name (dev, staging, prod)
  String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 'dev';
  }

  /// Test User Email (Debug Only)
  String? get testUserEmail {
    if (!isDebug) return null;
    return dotenv.env['TEST_USER_EMAIL'];
  }

  /// Test User Password (Debug Only)
  String? get testUserPassword {
    if (!isDebug) return null;
    return dotenv.env['TEST_USER_PASSWORD'];
  }
}

// Global config instance
final appConfig = AppConfig();
