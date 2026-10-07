enum AppMode {
  hcp,
  corenergy,
}

enum Environment {
  development,
  production,
}

class AppConfig {
  static AppMode mode = AppMode.hcp;

  // ===========================================================================
  // 🚀 SERVER ENVIRONMENT SWITCH (SINGLE-LINE TOGGLE)
  // Set to Environment.development or Environment.production
  // ===========================================================================
  static Environment environment = Environment.development;

  // Development Server URL
  static const String devServerUrl = 'https://dev.pmii-marketing.com';

  // Production Server URL (update to your company's production domain when ready)
  static const String prodServerUrl = 'https://pmii-marketing.com';

  /// Active server URL determined dynamically by the environment setting
  static String get serverUrl =>
      environment == Environment.production ? prodServerUrl : devServerUrl;
}

