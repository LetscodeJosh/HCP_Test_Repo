import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/services/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clear();
  });

  group('AppLogger Technical Debt Protection Tests', () {
    test('Logs are captured in in-memory ring buffer with correct levels', () {
      AppLogger.i('TEST_TAG', 'Information message');
      AppLogger.w('TEST_TAG', 'Warning message');
      AppLogger.e('TEST_TAG', 'Error message', 'SimulatedException');

      final logs = AppLogger.getRecentLogs();
      expect(logs.length, 3);
      expect(logs[0].level, LogLevel.info);
      expect(logs[0].message, 'Information message');
      expect(logs[1].level, LogLevel.warning);
      expect(logs[2].level, LogLevel.error);
      expect(logs[2].error, 'SimulatedException');
    });

    test('Sensitive data (passwords, tokens) is automatically redacted', () {
      AppLogger.i('AUTH', 'Login payload: usr=admin&password=SuperSecretPassword123&other=value');
      AppLogger.w('API', 'Token expired: token=abc123xyz456');

      final logs = AppLogger.getRecentLogs();
      expect(logs[0].message, contains('password=[REDACTED]'));
      expect(logs[0].message, isNot(contains('SuperSecretPassword123')));
      expect(logs[1].message, contains('token=[REDACTED]'));
      expect(logs[1].message, isNot(contains('abc123xyz456')));
    });

    test('In-memory buffer respects max limit without memory leaks', () {
      for (int i = 0; i < AppLogger.maxBufferSize + 50; i++) {
        AppLogger.d('BENCHMARK', 'Message #$i');
      }

      final logs = AppLogger.getRecentLogs();
      expect(logs.length, AppLogger.maxBufferSize);
      expect(logs.last.message, 'Message #${AppLogger.maxBufferSize + 49}');
    });

    test('Exporting diagnostic telemetry generates formatted report', () {
      AppLogger.i('INIT', 'System initialized successfully');
      AppLogger.w('NETWORK', 'Transient timeout recovered');

      final report = AppLogger.exportLogsAsText();
      expect(report, contains('PIMS HCP Profiling Diagnostic Telemetry Report'));
      expect(report, contains('[INIT] System initialized successfully'));
      expect(report, contains('[NETWORK] Transient timeout recovered'));
    });
  });
}
