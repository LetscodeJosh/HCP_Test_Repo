import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Severity levels for enterprise telemetry and diagnostic logging.
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// A structured log entry capturing runtime diagnostics.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'tag': tag,
        'message': message,
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19);
    final lvl = level.name.toUpperCase().padRight(5);
    final errStr = error != null ? ' | Error: $error' : '';
    return '[$timeStr] [$lvl] [$tag] $message$errStr';
  }
}

/// Enterprise production logging framework designed to prevent technical debt:
/// - Eliminates raw print() noise and performance degradation
/// - Stores an in-memory rotating ring buffer (500 entries) for field diagnostics
/// - Redacts sensitive tokens/passwords automatically
/// - Supports 1-click diagnostic export for field support
class AppLogger {
  AppLogger._();

  static const int maxBufferSize = 500;
  static final Queue<LogEntry> _logBuffer = Queue<LogEntry>();
  static bool enableDiagnosticsInRelease = false;

  /// Sensitive keywords that are sanitized automatically.
  static final RegExp _sensitivePattern = RegExp(
    r'(password|pwd|secret|token|api_secret|usr_pwd)=[^&,\s]+',
    caseSensitive: false,
  );

  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Sanitize message from sensitive credentials
    final sanitizedMessage = message.replaceAllMapped(
      _sensitivePattern,
      (match) => '${match.group(1)}=[REDACTED]',
    );

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: sanitizedMessage,
      error: error,
      stackTrace: stackTrace,
    );

    // Maintain in-memory diagnostic buffer
    if (_logBuffer.length >= maxBufferSize) {
      _logBuffer.removeFirst();
    }
    _logBuffer.addLast(entry);

    // In debug mode or if diagnostics enabled: output formatted string
    if (kDebugMode || enableDiagnosticsInRelease || level == LogLevel.warning || level == LogLevel.error) {
      debugPrint(entry.toString());
      if (error != null && level == LogLevel.error) {
        debugPrint('  Details: $error');
      }
    }
  }

  static void v(String tag, String message) => log(LogLevel.verbose, tag, message);
  static void d(String tag, String message) => log(LogLevel.debug, tag, message);
  static void i(String tag, String message) => log(LogLevel.info, tag, message);
  static void w(String tag, String message, [Object? err]) => log(LogLevel.warning, tag, message, error: err);
  static void e(String tag, String message, [Object? err, StackTrace? stack]) =>
      log(LogLevel.error, tag, message, error: err, stackTrace: stack);

  /// Returns recent diagnostic log entries.
  static List<LogEntry> getRecentLogs() => List.unmodifiable(_logBuffer);

  /// Exports diagnostic logs as a clean plaintext string for IT support.
  static String exportLogsAsText() {
    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln('  PIMS HCP Profiling Diagnostic Telemetry Report');
    buffer.writeln('  Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('================================================================');
    for (final entry in _logBuffer) {
      buffer.writeln(entry.toString());
    }
    return buffer.toString();
  }

  /// Clears in-memory buffer.
  static void clear() => _logBuffer.clear();
}
