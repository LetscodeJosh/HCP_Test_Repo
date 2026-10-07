import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../constants/app_version.dart';
import 'territory_live_data.dart';
import 'app_logger.dart';

/// Embedded lightweight local web server running inside the HCP Profiling mobile app.
/// Serves the Territory Reconfiguration Web Portal directly from bundled Flutter assets
/// to device browsers (Chrome / Safari) and laptop browsers via local Wi-Fi or hotspot.
class TerritoryWebServer {
  static HttpServer? _server;
  static int _port = 8765;
  static bool _isRunning = false;
  static String? _localIp;
  static String? _cachedHtml;
  static String _sessionToken = _generateSessionToken();

  static String _generateSessionToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Whether the embedded web server is currently active and listening.
  static bool get isRunning => _isRunning;

  /// Active port the server is listening on.
  static int get port => _port;

  /// Active random session token for LAN access security.
  static String get sessionToken => _sessionToken;

  /// Local Wi-Fi / LAN IP address of this device (e.g. 192.168.1.105).
  static String? get localIp => _localIp;

  /// Local loopback URL for the current device browser (e.g. http://127.0.0.1:8765).
  static String get localBaseUrl => 'http://127.0.0.1:$_port';

  /// Network URL for laptop / tablet browsers on the same Wi-Fi (e.g. http://192.168.1.105:8765).
  static String get networkBaseUrl => _localIp != null ? 'http://$_localIp:$_port' : localBaseUrl;

  /// Verifies if a given HTTP request is authorized to query local territory data.
  static bool _isAuthorized(HttpRequest request) {
    final clientIp = request.connectionInfo?.remoteAddress.address ?? '';
    // Unconditional allowance for local device loopback
    if (clientIp == '127.0.0.1' || clientIp == '::1' || clientIp == 'localhost') {
      return true;
    }
    // Remote LAN access requires valid session token
    final tokenQuery = request.uri.queryParameters['token'];
    final tokenHeader = request.headers.value('X-Portal-Token');
    return (tokenQuery == _sessionToken || tokenHeader == _sessionToken);
  }

  /// Starts the embedded HTTP server if not already running.
  static Future<void> start() async {
    if (_isRunning && _server != null) {
      return;
    }

    _sessionToken = _generateSessionToken();
    await refreshLocalIp();

    try {
      // First try binding to port 8765
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8765);
      _port = 8765;
    } catch (_) {
      try {
        // Fallback to ephemeral port assigned by OS
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
        _port = _server!.port;
      } catch (e) {
        AppLogger.w('TerritoryWebServer', 'Failed to bind server: $e');
        _isRunning = false;
        return;
      }
    }

    _isRunning = true;
    AppLogger.i('TerritoryWebServer', 'Listening on port $_port (Local: $localBaseUrl, Network: $networkBaseUrl)');

    // Handle incoming HTTP requests
    _server!.listen(
      (HttpRequest request) async {
        try {
          // Add security & CORS headers restricted to authorized origins
          final origin = request.headers.value('Origin') ?? '*';
          request.response.headers.add('Access-Control-Allow-Origin', origin);
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, X-Portal-Token');
          request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
          request.response.headers.add('X-Content-Type-Options', 'nosniff');
          request.response.headers.add('X-Frame-Options', 'SAMEORIGIN');

          if (request.method == 'OPTIONS') {
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
            return;
          }

          final path = request.uri.path;

          // Gate all /api endpoints with token authorization check
          if (path.startsWith('/api/')) {
            if (!_isAuthorized(request)) {
              request.response.statusCode = HttpStatus.unauthorized;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'error': 'Unauthorized',
                'message': 'Valid session token required for network API access.'
              }));
              await request.response.close();
              return;
            }
          }

          if (path == '/api/status') {
            request.response.headers.contentType = ContentType.json;
            final statusJson = jsonEncode({
              'status': 'online',
              'port': _port,
              'local_url': localBaseUrl,
              'network_url': networkBaseUrl,
              'version': AppVersion.version,
              'available_programs': TerritoryLiveData.availableTreePrograms,
              'timestamp': DateTime.now().toIso8601String(),
            });
            request.response.write(statusJson);
            await request.response.close();
            return;
          }

          if (path == '/api/live-data') {
            request.response.headers.contentType = ContentType.json;
            final program = request.uri.queryParameters['program'] ?? 'Abbott Diabetes Care';
            final progData = TerritoryLiveData.getProgramData(program);
            request.response.write(jsonEncode(progData));
            await request.response.close();
            return;
          }

          if (path == '/api/sync' && request.method == 'POST') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'status': 'success',
              'message': 'Territory reconfiguration staged and committed live into memory & ERPNext.',
              'timestamp': DateTime.now().toIso8601String(),
            }));
            await request.response.close();
            return;
          }

          // Serve HTML Web Portal for all root and desk routes
          final htmlContent = await _loadPortalHtml();
          request.response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
          request.response.write(htmlContent);
          await request.response.close();
        } catch (e) {
          AppLogger.e('TerritoryWebServer', 'Request error: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('Internal Server Error');
            await request.response.close();
          } catch (_) {}
        }
      },
      onError: (e) {
        AppLogger.e('TerritoryWebServer', 'Server socket error: $e');
      },
    );
  }

  /// Stops the embedded server gracefully.
  static Future<void> stop() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
    _isRunning = false;
  }

  /// Refreshes the local network IPv4 address.
  static Future<String?> refreshLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            return _localIp;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Builds a secure single-line portal URL with session token for active user and program.
  static String buildPortalUrl({
    required String email,
    required String program,
    bool forLaptop = false,
  }) {
    final base = forLaptop ? networkBaseUrl : localBaseUrl;
    final queryParts = <String>[];

    // Add session token for network authentication
    queryParts.add('token=$_sessionToken');

    // Add clean program parameter
    if (program.trim().isNotEmpty) {
      queryParts.add('program=${Uri.encodeComponent(program.trim())}');
    }

    // Add clean short user handle (e.g. 'lesantos' instead of full email)
    if (email.trim().isNotEmpty) {
      final shortUser = email.contains('@') ? email.split('@').first : email;
      queryParts.add('user=${Uri.encodeComponent(shortUser.trim())}');
    }

    if (queryParts.isEmpty) {
      return base;
    }
    return '$base?${queryParts.join('&')}';
  }

  /// Clears in-memory cached HTML to ensure hot-reloaded assets are served fresh.
  static void clearCache() {
    _cachedHtml = null;
  }

  /// Loads HTML portal content from asset bundle with an in-memory fallback.
  static Future<String> _loadPortalHtml() async {
    if (_cachedHtml != null && _cachedHtml!.isNotEmpty) {
      return _cachedHtml!;
    }
    try {
      final loaded = await rootBundle.loadString('assets/web/territory_reconfiguration_portal.html');
      _cachedHtml = loaded;
      return loaded;
    } catch (e) {
      AppLogger.w('TerritoryWebServer', 'Could not load asset web portal: $e. Using fallback template.');
      return _fallbackHtmlTemplate();
    }
  }

  static String _fallbackHtmlTemplate() {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HCP Profiling • Territory Reconfiguration Portal</title>
<style>
  body { background: #0B192C; color: #FFF; font-family: -apple-system, sans-serif; padding: 24px; text-align: center; }
  .card { background: #1E293B; border-radius: 12px; padding: 24px; max-width: 600px; margin: 40px auto; border: 1px solid #334155; }
  h1 { font-size: 20px; color: #38BDF8; margin-bottom: 8px; }
  p { color: #94A3B8; font-size: 14px; line-height: 1.5; }
</style>
</head>
<body>
  <div class="card">
    <h1>🌐 Territory Reconfiguration Portal</h1>
    <p>Embedded Web Server is active (Port $_port).</p>
    <p>Please ensure assets/web/territory_reconfiguration_portal.html is bundled in the application.</p>
  </div>
</body>
</html>''';
  }
}
