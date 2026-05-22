import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Hive (cache local des messages)
  await Hive.initFlutter();

  // Handler FCM en arrière-plan — non supporté sur web (service worker)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialisation des notifications (Firebase + local)
  // firebase_options.dart est généré par : flutterfire configure
  await NotificationService.instance.initialize(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar transparente pour le thème sombre
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141414),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    const ProviderScope(
      child: ArcanaApp(),
    ),
  );
}
