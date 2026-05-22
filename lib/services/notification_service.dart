import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../widgets/notification_banner.dart';

// Ignoré si firebase_options.dart n'existe pas encore
// ignore: uri_does_not_exist
// import '../firebase_options.dart';

/// NotificationService
/// ─────────────────────────────────────────────────────────
/// Gère :
///   1. Initialisation Firebase + FCM
///   2. Permissions push (Android 13+ / iOS)
///   3. Enregistrement du token FCM vers le backend
///   4. Réception des messages (foreground → banner local)
///   5. Navigation au tap sur une notification
/// ─────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _localNotif = FlutterLocalNotificationsPlugin();
  final _api        = ApiClient();
  bool _initialized = false;

  // Callback appelé quand l'utilisateur tape sur une notification
  void Function(Map<String, dynamic> payload)? onNotificationTap;

  // Callback déclenché quand l'admin modifie un planning (schedule_created/updated/deleted)
  VoidCallback? onScheduleUpdated;

  // Callback déclenché quand un message FCM arrive en foreground
  // Permet d'injecter la notification dans le provider sans que le service
  // dépende directement de Riverpod.
  void Function(Map<String, dynamic> data)? onNewNotification;

  // ── Canal Android ────────────────────────────────────────
  static const _androidChannel = AndroidNotificationChannel(
    'arcana_schedule',
    'Emploi du temps',
    description: 'Notifications de séances et modifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialisation principale — à appeler dans main()
  /// [firebaseOptions] : DefaultFirebaseOptions.currentPlatform
  ///   (généré par flutterfire configure → lib/firebase_options.dart)
  Future<void> initialize({FirebaseOptions? firebaseOptions}) async {
    if (_initialized) return;
    _initialized = true;
    _firebaseOptions = firebaseOptions;

    if (kIsWeb) return; // Notifications non supportées sur web

    await _initLocalNotifications();
    await _initFirebase();
  }

  FirebaseOptions? _firebaseOptions;

  // ── Local Notifications ──────────────────────────────────
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotif.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // Tap sur notif locale
        _handlePayload(details.payload);
      },
    );

    // Créer le canal Android
    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  // ── Firebase + FCM ──────────────────────────────────────
  Future<void> _initFirebase() async {
    try {
      // Initialisation avec les options générées par flutterfire configure
      await Firebase.initializeApp(options: _firebaseOptions);

      final messaging = FirebaseMessaging.instance;

      // Demande de permission
      final settings = await messaging.requestPermission(
        alert:         true,
        badge:         true,
        sound:         true,
        announcement:  false,
        carPlay:       false,
        criticalAlert: false,
        provisional:   false,
      );

      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Foreground : afficher les notifications quand l'app est ouverte
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Écoute foreground
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Tap depuis background / terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // App ouverte depuis notification (terminated state)
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onMessageOpenedApp(initial);

      // Envoyer le token FCM au backend
      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);

      // Actualiser si le token change (rare)
      messaging.onTokenRefresh.listen(_registerToken);
    } catch (e) {
      // Firebase non configuré → FCM désactivé, notifs BDD uniquement
      debugPrint('FCM non disponible (google-services.json manquant?): $e');
    }
  }

  // ── Réception message foreground ────────────────────────
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    final title = notif?.title ?? message.data['title'] as String? ?? 'Arcana Tech';
    final body  = notif?.body  ?? message.data['body']  as String? ?? '';

    // Si c'est un changement de planning → rafraîchir l'emploi du temps
    final dataType = message.data['type'] as String? ?? '';
    if (dataType.startsWith('schedule_') || dataType == 'timetable') {
      onScheduleUpdated?.call();
    }

    // Injecter la notification dans le provider (mise à jour immédiate de la liste)
    onNewNotification?.call(message.data);

    // Déterminer le type de notification pour la couleur/icône du banner
    final bannerType = _bannerTypeFromData(message.data);

    // Afficher le banner WhatsApp-style en foreground
    BannerService.instance.show(
      title: title,
      body:  body,
      type:  bannerType,
      onTap: () => onNotificationTap?.call(message.data),
    );

    // Garder aussi la notification système (background drawer) si besoin
    if (notif != null) {
      await _showLocalNotification(
        title:   title,
        body:    body,
        payload: message.data,
      );
    }
  }

  BannerType _bannerTypeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'schedule_created': return BannerType.added;
      case 'schedule_updated': return BannerType.modified;
      case 'schedule_deleted': return BannerType.deleted;
      default:                 return BannerType.schedule;
    }
  }

  // ── Tap depuis arrière-plan ──────────────────────────────
  void _onMessageOpenedApp(RemoteMessage message) {
    // Rafraîchir le planning si c'est une notification de planning
    final dataType = message.data['type'] as String? ?? '';
    if (dataType.startsWith('schedule_') || dataType == 'timetable') {
      onScheduleUpdated?.call();
    }
    onNotificationTap?.call(message.data);
  }

  // ── Afficher une notification locale ────────────────────
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic> payload = const {},
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'arcana_schedule',
      'Emploi du temps',
      channelDescription: 'Notifications de séances',
      importance: Importance.high,
      priority:   Priority.high,
      icon:       '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload.toString(),
    );
  }

  // ── Payload tap ─────────────────────────────────────────
  void _handlePayload(String? payload) {
    if (payload == null) return;
    onNotificationTap?.call({'raw': payload});
  }

  // ── Enregistrer le token FCM auprès du backend ──────────
  Future<void> _registerToken(String token) async {
    try {
      await _api.dio.post(ApiEndpoints.fcmToken, data: {
        'token':    token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('Token FCM enregistré: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Erreur enregistrement token FCM: $e');
    }
  }

  /// Supprimer le token FCM du backend (appelé au logout)
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _api.dio.delete(ApiEndpoints.fcmToken, data: {'token': token});
      }
    } catch (_) {}
  }
}

// Nécessaire pour la réception en background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Message en arrière-plan: ${message.messageId}');
}
