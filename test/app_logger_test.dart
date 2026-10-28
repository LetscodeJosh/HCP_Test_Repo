import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/services/app_logger.dart';
import 'package:hcp_profiling/screens/components/local_qr_code_widget.dart';

void main() {
  setUp(() {
    AppLogger.clear();
  });

  group('AppLogger Technical Debt & Security Redaction Tests', () {
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

    test('Sensitive data (passwords, tokens, JSON fields, sid cookies, Bearer headers) is automatically redacted', () {
      AppLogger.i('AUTH', 'Login payload: usr=admin&password=SuperSecretPassword123&other=value');
      AppLogger.w('API', 'Token expired: token=abc123xyz456');
      AppLogger.d('JSON', '{"usr":"rep@example.com","pwd":"MyJsonSecret99","sid":"987654321abcdef","csrf_token":"tok_123"}');
      AppLogger.d('HDR', 'Cookie: sid=deadbeefcafe123; Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig');

      final logs = AppLogger.getRecentLogs();
      expect(logs[0].message, contains('password=[REDACTED]'));
      expect(logs[0].message, isNot(contains('SuperSecretPassword123')));
      expect(logs[1].message, contains('token=[REDACTED]'));
      expect(logs[1].message, isNot(contains('abc123xyz456')));
      expect(logs[2].message, contains('"pwd":"[REDACTED]"'));
      expect(logs[2].message, contains('"sid":"[REDACTED]"'));
      expect(logs[2].message, contains('"csrf_token":"[REDACTED]"'));
      expect(logs[2].message, isNot(contains('MyJsonSecret99')));
      expect(logs[2].message, isNot(contains('987654321abcdef')));
      expect(logs[3].message, contains('sid=[REDACTED]'));
      expect(logs[3].message, contains('Bearer [REDACTED]'));
      expect(logs[3].message, isNot(contains('deadbeefcafe123')));
      expect(logs[3].message, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
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

    test('LocalQrCodeWidget instantiates cleanly without external network URLs', () {
      const widget = LocalQrCodeWidget(
        data: 'http://192.168.1.10:8765/?token=abc123def456',
        size: 180,
      );
      expect(widget.data, contains('token=abc123def456'));
      expect(widget.size, 180);
    });
  });
}
