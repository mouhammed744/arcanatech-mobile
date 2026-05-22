import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/secure_storage.dart';
import '../models/user.dart';
import '../services/notification_service.dart';
import '../services/oauth_service.dart';
import 'notification_provider.dart';
import 'theme_provider.dart';

class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  // 2FA
  final bool twoFactorRequired;
  final String? challengeToken;
  final String? twoFactorMethod;
  // Social login completion
  final bool needsProfileCompletion;
  final String? socialName;
  final String? socialEmail;
  final String? socialProvider;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.twoFactorRequired = false,
    this.challengeToken,
    this.twoFactorMethod,
    this.needsProfileCompletion = false,
    this.socialName,
    this.socialEmail,
    this.socialProvider,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    bool? twoFactorRequired,
    String? challengeToken,
    String? twoFactorMethod,
    bool? needsProfileCompletion,
    String? socialName,
    String? socialEmail,
    String? socialProvider,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        twoFactorRequired: twoFactorRequired ?? this.twoFactorRequired,
        challengeToken: challengeToken ?? this.challengeToken,
        twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
        needsProfileCompletion: needsProfileCompletion ?? this.needsProfileCompletion,
        socialName: socialName ?? this.socialName,
        socialEmail: socialEmail ?? this.socialEmail,
        socialProvider: socialProvider ?? this.socialProvider,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final _api = ApiClient();
  final _storage = SecureStorageService();

  AuthNotifier(this.ref) : super(const AuthState());

  /// Vérifie si un token existe au démarrage
  Future<bool> checkAuth() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = const AuthState();
      return false;
    }

    try {
      final response = await _api.dio.get(ApiEndpoints.me);
      final user = User.fromJson(response.data as Map<String, dynamic>);
      state = AuthState(user: user, isAuthenticated: true);
      ref.read(themeProvider.notifier).applyUniversityTheme(user.university);
      ref.read(notificationProvider.notifier).fetchNotifications();
      return true;
    } catch (_) {
      // Token invalide ou backend inaccessible → retour à la connexion
      await _storage.clearTokens();
      state = const AuthState();
      return false;
    }
  }

  /// Connexion email + mot de passe
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;

      // Vérifier si le 2FA est requis (le backend renvoie 'requires2fa', pas 'twoFactorRequired')
      if (data['requires2fa'] == true) {
        state = AuthState(
          twoFactorRequired: true,
          challengeToken: data['challengeToken'] as String?,
          twoFactorMethod: data['method'] as String?,
        );
        return;
      }

      // Pas de 2FA — login normal
      final loginData = LoginResponse.fromJson(data);

      await _storage.saveTokens(
        accessToken: loginData.tokens.accessToken,
        refreshToken: loginData.tokens.refreshToken,
      );

      state = AuthState(
        user: loginData.user,
        isAuthenticated: true,
      );

      ref
          .read(themeProvider.notifier)
          .applyUniversityTheme(loginData.user.university);

      // Charger les notifications au login
      ref.read(notificationProvider.notifier).fetchNotifications();

      // Charger le profil complet (avec données étudiant)
      _fetchProfile();
    } on DioException catch (e) {
      String message = 'Identifiants incorrects. Vérifiez votre email et mot de passe.';
      if (e.response?.data is Map) {
        final msg = e.response!.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) message = msg;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur est survenue. Vérifiez votre connexion et réessayez.',
      );
    }
  }

  /// Compléter le challenge 2FA
  Future<void> verify2FA(String code) async {
    if (state.challengeToken == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _api.dio.post(
        ApiEndpoints.twoFactorChallenge,
        data: {
          'code': code,
          'challengeToken': state.challengeToken,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final loginData = LoginResponse.fromJson(data);

      await _storage.saveTokens(
        accessToken: loginData.tokens.accessToken,
        refreshToken: loginData.tokens.refreshToken,
      );

      state = AuthState(
        user: loginData.user,
        isAuthenticated: true,
      );

      ref
          .read(themeProvider.notifier)
          .applyUniversityTheme(loginData.user.university);

      _fetchProfile();
    } on DioException catch (e) {
      String message = 'Code invalide';
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        message = e.response!.data['message'] as String;
      }
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  /// Charger le profil complet (avec données étudiant via /me)
  Future<void> _fetchProfile() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.me);
      final user = User.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(user: user);
      ref.read(themeProvider.notifier).applyUniversityTheme(user.university);
    } catch (_) {
      // Silencieux - on a déjà les données du login
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      await _api.dio.post(ApiEndpoints.logout);
    } catch (_) {}

    // Supprimer le token FCM du backend avant de se déconnecter
    await NotificationService.instance.unregisterToken();

    await _storage.clearTokens();
    ref.read(themeProvider.notifier).reset();
    state = const AuthState();
  }

  /// Connexion via réseau social (Google, Apple, TikTok)
  Future<void> socialLogin(String provider) async {
    state = state.copyWith(isLoading: true, clearError: true);

    OAuthResult? result;

    try {
      switch (provider) {
        case 'google':
          result = await OAuthService.instance.signInWithGoogle();
          break;
        case 'apple':
          result = await OAuthService.instance.signInWithApple();
          break;
        case 'tiktok':
          result = await OAuthService.instance.signInWithTikTok();
          break;
        default:
          throw Exception('Provider inconnu : $provider');
      }

      if (result == null) {
        // Annulé par l'utilisateur
        state = state.copyWith(isLoading: false);
        return;
      }

      // Envoyer le token au backend
      final response = await _api.dio.post(
        ApiEndpoints.socialLogin,
        data: {
          'provider': result.provider,
          'token': result.token,
          if (result.email != null) 'email': result.email,
          if (result.name != null) 'name': result.name,
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Si le backend demande une complétion de profil
      if (data['needsProfileCompletion'] == true) {
        state = state.copyWith(
          isLoading: false,
          needsProfileCompletion: true,
          socialName: result.name ?? data['name'] as String?,
          socialEmail: result.email ?? data['email'] as String?,
          socialProvider: provider,
        );
        return;
      }

      final loginData = LoginResponse.fromJson(data);

      await _storage.saveTokens(
        accessToken: loginData.tokens.accessToken,
        refreshToken: loginData.tokens.refreshToken,
      );

      state = AuthState(user: loginData.user, isAuthenticated: true);

      ref.read(themeProvider.notifier).applyUniversityTheme(loginData.user.university);
      ref.read(notificationProvider.notifier).fetchNotifications();
      _fetchProfile();
    } on DioException catch (e) {
      String message = 'Connexion $provider impossible.';
      if (e.response?.data is Map) {
        final msg = e.response!.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) message = msg;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Connexion $provider impossible');
    }
  }

  /// Compléter le profil après une connexion sociale
  Future<void> completeSocialProfile(Map<String, String> data) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Décomposer le nom complet en prénom + nom (attendu par le backend)
      final nameParts  = (state.socialName ?? '').trim().split(' ');
      final firstName  = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName   = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

      final response = await _api.dio.post(
        ApiEndpoints.registerStudent,
        data: {
          'first_name'           : firstName,
          'last_name'            : lastName,
          'email'                : state.socialEmail ?? data['email'] ?? '',
          'phone'                : data['phone'] ?? '',
          'password'             : data['password'] ?? '',
          'password_confirmation': data['password'] ?? '',
          'filiere'              : data['filiere'] ?? '',
          'level'                : data['niveau'] ?? '',
        },
      );

      final loginData = LoginResponse.fromJson(response.data as Map<String, dynamic>);

      await _storage.saveTokens(
        accessToken: loginData.tokens.accessToken,
        refreshToken: loginData.tokens.refreshToken,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        needsProfileCompletion: false,
        user: loginData.user,
      );

      ref.read(themeProvider.notifier).applyUniversityTheme(loginData.user.university);
    } on DioException catch (e) {
      String message = 'Impossible de compléter le profil.';
      if (e.response?.data is Map) {
        final msg = e.response!.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) message = msg;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Une erreur est survenue. Réessayez.',
      );
    }
  }

  /// Envoie un email de réinitialisation du mot de passe
  Future<void> sendForgotPassword(String email) async {
    await _api.dio.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );
  }

  /// Met à jour l'avatar
  Future<void> updateAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _api.dio.post(ApiEndpoints.avatar, data: formData);
      final avatarUrl = response.data['avatar'] as String?;
      if (avatarUrl != null && state.user != null) {
        final updatedUser = User.fromJson({
          ...state.user!.toJson(),
          'avatar': avatarUrl,
        });
        state = state.copyWith(user: updatedUser);
      }
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
