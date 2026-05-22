import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Résultat d'une authentification sociale
class OAuthResult {
  final String provider; // 'google' | 'apple' | 'tiktok'
  final String token;    // idToken ou code selon le provider
  final String? email;
  final String? name;

  const OAuthResult({
    required this.provider,
    required this.token,
    this.email,
    this.name,
  });
}

// ─── OAuthService ─────────────────────────────────────────────────────────────

class OAuthService {
  OAuthService._();
  static final OAuthService instance = OAuthService._();

  // ── Google ───────────────────────────────────────────────────────────────────
  //
  // CONFIGURATION REQUISE :
  // 1. Firebase Console → Authentication → Sign-in method → Google → Activer
  // 2. Télécharger le nouveau google-services.json (oauth_client sera rempli)
  // 3. Coller le Web Client ID ci-dessous (Google Cloud Console → Identifiants
  //    → "Client Web (créé automatiquement par Google Service)")
  //    Format : XXXXXXXX-XXXX.apps.googleusercontent.com
  //
  // Web Client ID = GOOGLE_CLIENT_ID dans le .env Laravel
  static const _googleServerClientId =
      '913330822210-m0ubu3cjat5us30g6klqubdfcudqjs1l.apps.googleusercontent.com';

  late final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web : clientId uniquement — serverClientId non supporté
    // Android/iOS : serverClientId uniquement
    clientId:       kIsWeb ? _googleServerClientId : null,
    serverClientId: kIsWeb ? null : _googleServerClientId,
  );

  Future<OAuthResult?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ── Web ───────────────────────────────────────────────────────────────
        // • signOut() sur web force une re-initialisation GIS → warning "called
        //   multiple times" → on ne l'appelle PAS.
        // • signInSilently() déclenche aussi une initialisation GIS supplémentaire
        //   (One Tap) puis échoue avec opt_out_or_no_session si aucune session
        //   n'existe → on l'évite également.
        // • On appelle directement signIn() ; toutes les erreurs de flow normal
        //   (popup_closed, popup_blocked, opt_out_or_no_session, access_denied)
        //   sont interceptées ci-dessous et traitées comme une annulation.
      } else {
        // ── Mobile : forcer l'affichage du sélecteur de compte ───────────────
        await _googleSignIn.signOut();
      }

      final account = await _googleSignIn.signIn();
      if (account == null) return null; // Annulé par l'utilisateur

      final auth = await account.authentication;

      // idToken est préférable (vérifié côté serveur) ; fallback sur accessToken
      final token = auth.idToken ?? auth.accessToken;
      if (token == null) {
        throw Exception(
          'Token Google introuvable. '
          'Vérifiez que le Web Client ID est configuré dans firebase_options '
          'et que Google Auth est activé dans Firebase Console.',
        );
      }

      return OAuthResult(
        provider: 'google',
        token: token,
        email: account.email,
        name: account.displayName,
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');

      // Erreurs de flux normal → annulation silencieuse (pas de message d'erreur UI)
      final msg = e.toString();
      if (msg.contains('popup_closed')         ||
          msg.contains('popup_blocked')         ||
          msg.contains('opt_out_or_no_session') ||
          msg.contains('access_denied')) {
        return null;
      }

      // ApiException 10 = DEVELOPER_ERROR → oauth_client vide ou SHA-1 manquant
      if (msg.contains('ApiException: 10') || msg.contains('10:')) {
        throw Exception(
          'Google Sign-In non configuré.\n'
          '1. Firebase Console → Authentication → Google → Activer\n'
          '2. Télécharger le nouveau google-services.json\n'
          '3. Ajouter le SHA-1 du keystore dans Firebase.',
        );
      }
      rethrow;
    }
  }

  // ── Apple ─────────────────────────────────────────────────────────────────────

  Future<OAuthResult?> signInWithApple() async {
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final token = cred.identityToken;
      if (token == null) throw Exception('Token Apple introuvable');

      final name = [cred.givenName, cred.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');

      return OAuthResult(
        provider: 'apple',
        token: token,
        email: cred.email,
        name: name.isEmpty ? null : name,
      );
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }

  // ── TikTok ────────────────────────────────────────────────────────────────────
  //
  // CONFIGURATION REQUISE (Android) :
  // AndroidManifest.xml doit déclarer com.linusu.flutter_web_auth_2.CallbackActivity
  // avec le scheme "arcanatech" → déjà fait dans ce projet.
  //
  // TikTok Developer Portal → App → Login Kit → Redirect URI :
  //   arcanatech://oauth/tiktok
  //
  static const _tiktokClientKey  = 'awyggtij427l6cqm';
  static const _tiktokRedirectUri = 'arcanatech://oauth/tiktok';

  Future<OAuthResult?> signInWithTikTok() async {
    try {
      final authUrl = Uri.https('www.tiktok.com', '/v2/auth/authorize', {
        'client_key':    _tiktokClientKey,
        'scope':         'user.info.basic,user.info.profile',
        'response_type': 'code',
        'redirect_uri':  _tiktokRedirectUri,
        'state':         DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Ouvre Chrome Custom Tab et attend le redirect arcanatech://...
      final result = await FlutterWebAuth2.authenticate(
        url:               authUrl.toString(),
        callbackUrlScheme: 'arcanatech',
      );

      final uri  = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        if (error == 'access_denied') return null; // Annulé
        throw Exception('TikTok OAuth erreur: $error');
      }

      if (code == null) return null;

      // Le backend reçoit ce code et l'échange contre un access_token via l'API TikTok
      return OAuthResult(
        provider: 'tiktok',
        token:    code,
      );
    } catch (e) {
      if (e.toString().contains('UserCancel') ||
          e.toString().contains('user_cancel') ||
          e.toString().contains('CANCELED')) {
        return null; // Annulé par l'utilisateur
      }
      debugPrint('TikTok Sign-In error: $e');
      rethrow;
    }
  }
}
