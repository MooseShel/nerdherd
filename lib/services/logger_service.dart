import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Singleton logger service for the application
/// Provides structured logging with different levels and conditional output
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  late final Logger _logger;

  // Callback for remote logging or analytics
  Function(String level, String message, dynamic error, StackTrace? stackTrace)?
      _onLog;

  /// Initialize the logger with custom configuration.
  ///
  /// Uses [ProductionFilter] to log even in release mode (can be adjusted).
  /// Uses [PrettyPrinter] for formatted output.
  void initialize({
    LogFilter? filter,
    LogPrinter? printer,
    LogOutput? output,
    Level? level,
    Function(String level, String message, dynamic error,
            StackTrace? stackTrace)?
        onLog,
  }) {
    _onLog = onLog;
    _logger = Logger(
      filter: filter ?? ProductionFilter(),
      printer: printer ??
          PrettyPrinter(
            methodCount: 0, // Don't include stack trace
            errorMethodCount: 5, // Include stack trace for errors
            lineLength: 80,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
      output: output,
      level: level ?? (kDebugMode ? Level.debug : Level.info),
    );
  }

  /// Log a debug message (only visible in debug mode).
  ///
  /// Use this for verbose info useful for development but noise in production.
  void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message.
  ///
  /// Use this for general application flow events (e.g. startup, init success).
  void info(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message.
  ///
  /// Use this for non-critical issues that should be looked at but don't crash the app.
  void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message.
  ///
  /// Use this for exceptions and runtime errors that impact functionality.
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    String errorMsg = message;
    if (error != null) {
      try {
        errorMsg += " | Error: ${error.toString()}";
      } catch (_) {
        errorMsg += " | Error: <Complex Object>";
      }
    }
    // Pass null as error to avoid Logger inspecting the object
    _logger.e(errorMsg, error: null, stackTrace: stackTrace);
    _onLog?.call('error', message, error, stackTrace);
  }

  /// Log a fatal/critical error.
  ///
  /// Use this for catastrophic failures requiring immediate attention.
  void fatal(String message, {dynamic error, StackTrace? stackTrace}) {
    String errorMsg = message;
    if (error != null) {
      try {
        errorMsg += " | Error: ${error.toString()}";
      } catch (_) {
        errorMsg += " | Error: <Complex Object>";
      }
    }
    _logger.f(errorMsg, error: null, stackTrace: stackTrace);
    _onLog?.call('fatal', message, error, stackTrace);
  }
}

// Global logger instance for easy access
final logger = LoggerService();
