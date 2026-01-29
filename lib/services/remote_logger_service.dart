import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Service to handle sending application logs to Supabase
class RemoteLoggerService {
  final SupabaseClient _supabase;

  RemoteLoggerService(this._supabase);

  /// Send an error log to the Supabase database
  Future<void> logRemote({
    required String level,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    try {
      final user = _supabase.auth.currentUser;

      final logData = {
        'user_id': user?.id,
        'level': level,
        'message': message,
        'error_details': error?.toString(),
        'stack_trace': stackTrace?.toString(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('debug_logs').insert(logData);
    } catch (e) {
      // If remote logging fails, we just print locally to avoid infinite recursion
      debugPrint('❌ Failed to send remote log: $e');
    }
  }
}

// Global variable for remote logger, initialized in main()
RemoteLoggerService? remoteLogger;

/// Helper extension for LoggerService to support remote logging
extension RemoteLogging on LoggerService {
  void remoteError(String message, {dynamic error, StackTrace? stackTrace}) {
    this.error(message, error: error, stackTrace: stackTrace);
    remoteLogger?.logRemote(
      level: 'error',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void remoteFatal(String message, {dynamic error, StackTrace? stackTrace}) {
    this.fatal(message, error: error, stackTrace: stackTrace);
    remoteLogger?.logRemote(
      level: 'fatal',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
