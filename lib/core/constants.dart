import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class AppConstants {
  AppConstants._();

  // ── URLs ─────────────────────────────────────────────────────────────────────

  /// URL de production Railway
  static const String _productionUrl = 'https://arcanatech-backend-production.up.railway.app/api';

  /// IP LAN du PC de développement (pour téléphone physique en debug)
  static const String _lanIp = '192.168.1.105';

  /// Base URL — production en release, locale en debug
  static String get baseUrl {
    if (kReleaseMode) return _productionUrl;
    if (kIsWeb)       return 'http://localhost:8000/api';
    return 'http://$_lanIp:8000/api';
  }

  /// Timeouts
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;

  /// Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
}
