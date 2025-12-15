import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:nerd_herd/services/logger_service.dart';

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  group('LoggerService', () {
    setUpAll(() {
      // Initialize logger with silent output to prevent test failures from stderr
      logger.initialize(output: SilentOutput());
    });

    test('is a singleton', () {
      final logger1 = LoggerService();
      final logger2 = LoggerService();

      expect(identical(logger1, logger2), true);
    });

    test('provides global logger instance', () {
      expect(logger, isNotNull);
      expect(logger, isA<LoggerService>());
    });

    test('logging methods do not throw', () {
      expect(() => logger.debug('Debug message'), returnsNormally);
      expect(() => logger.info('Info message'), returnsNormally);
      expect(() => logger.warning('Warning message'), returnsNormally);
      expect(() => logger.error('Error message'), returnsNormally);
      expect(() => logger.fatal('Fatal message'), returnsNormally);
    });

    test('logging with error parameter does not throw', () {
      final testError = Exception('Test error');

      expect(
        () => logger.error('Error occurred', error: testError),
        returnsNormally,
      );
    });

    test('logging with stack trace does not throw', () {
      final testError = Exception('Test error');
      final stackTrace = StackTrace.current;

      expect(
        () => logger.error(
          'Error occurred',
          error: testError,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });
  });
}
