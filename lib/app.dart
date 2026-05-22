import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/scanner/scanner_screen.dart';
import 'screens/grades/grades_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/justification/justification_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'providers/notification_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'widgets/notification_banner.dart';

/// Clé globale du navigator — partagée avec BannerService et GoRouter
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // ── Routes autonomes (hors shell) ──────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CompleteProfileScreen(
            name: extra['name'] as String? ?? '',
            email: extra['email'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/scanner',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/attendance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/grades',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const GradesScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/justification',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const JustificationScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ── Shell : 3 branches + FAB Scanner central ──────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0 ─ Accueil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 1 ─ Planning
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          // 2 ─ Profil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ─── App principale ───────────────────────────────────────────────────────────

class ArcanaApp extends ConsumerStatefulWidget {
  const ArcanaApp({super.key});

  @override
  ConsumerState<ArcanaApp> createState() => _ArcanaAppState();
}

class _ArcanaAppState extends ConsumerState<ArcanaApp> {
  @override
  void initState() {
    super.initState();

    // ── Navigation vers Planning quand une notif planning est tappée ──────────
    NotificationService.instance.onNotificationTap = (data) {
      final type = data['type'] as String? ?? '';
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      if (type.startsWith('schedule_') || type == 'timetable') {
        ctx.go('/schedule');
      }
    };

    // ── Rafraîchir l'emploi du temps quand l'admin publie un planning ─────────
    NotificationService.instance.onScheduleUpdated = () {
      ref.read(scheduleProvider.notifier).loadSchedule();
    };

    // ── Ajouter la notification FCM dans la liste en temps réel ───────────────
    NotificationService.instance.onNewNotification = (data) {
      ref.read(notificationProvider.notifier).addFcmNotification(data);
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Connecter BannerService au navigator dès que l'app est construite
    BannerService.instance.navigatorKey = rootNavigatorKey;

    return MaterialApp.router(
      title: 'ARCANA TECH',
      debugShowCheckedModeBanner: false,
      theme: themeState.theme,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
