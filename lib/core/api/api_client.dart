import 'package:dio/dio.dart';
import '../constants.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = SecureStorageService();
  bool _isRefreshing = false;

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout:
          const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  /// Ajoute le token JWT à chaque requête
  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Intercepte les 401 pour auto-refresh du token
  Future<void> _onError(
      DioException error, ErrorInterceptorHandler handler) async {
    if (error.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(error);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _isRefreshing = false;
        return handler.next(error);
      }

      // Appel refresh sans interceptor pour éviter la boucle
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      final tokens = response.data['tokens'] as Map<String, dynamic>;
      final newAccessToken = tokens['accessToken'] as String;

      // Backend only returns new accessToken on refresh
      await _storage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );

      // Rejouer la requête originale avec le nouveau token
      final opts = error.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await dio.fetch(opts);
      _isRefreshing = false;
      return handler.resolve(retryResponse);
    } catch (_) {
      _isRefreshing = false;
      await _storage.clearTokens();
      return handler.next(error);
    }
  }
}
