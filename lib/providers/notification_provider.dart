import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/notification_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount   = 0,
    this.isLoading     = false,
    this.error,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        unreadCount:   unreadCount   ?? this.unreadCount,
        isLoading:     isLoading     ?? this.isLoading,
        error:         clearError ? null : (error ?? this.error),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NotificationNotifier extends StateNotifier<NotificationState> {
  final _api = ApiClient();

  NotificationNotifier() : super(const NotificationState());

  // ── Récupérer toutes les notifications (depuis l'API) ───────────────────────
  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'per_page': 50},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        notifications: items,
        unreadCount:   (data['unread_count'] as int?) ?? _countUnread(items),
        isLoading:     false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     'Impossible de charger les notifications.',
      );
    }
  }

  // ── Injecter une notification FCM en tête de liste (foreground) ─────────────
  /// Appelé depuis [NotificationService._onForegroundMessage]
  void addFcmNotification(Map<String, dynamic> fcmData) {
    final notif = NotificationModel.fromFcm(fcmData);
    state = state.copyWith(
      notifications: [notif, ...state.notifications],
      unreadCount:   state.unreadCount + 1,
    );
  }

  // ── Marquer une notification comme lue ──────────────────────────────────────
  Future<void> markAsRead(String id) async {
    final wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);

    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) =>
          n.id == id ? n.copyWith(isRead: true) : n).toList(),
      unreadCount: wasUnread
          ? (state.unreadCount - 1).clamp(0, 999)
          : state.unreadCount,
    );

    try {
      final resp = await _api.dio.post(ApiEndpoints.notificationRead(id));
      final newCount = (resp.data['unread_count'] as int?) ?? state.unreadCount;
      state = state.copyWith(unreadCount: newCount);
    } catch (_) {
      // Rollback si erreur réseau
      await fetchNotifications();
    }
  }

  // ── Tout marquer comme lu ────────────────────────────────────────────────────
  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);

    try {
      await _api.dio.post(ApiEndpoints.notificationsReadAll);
    } catch (_) {
      await fetchNotifications();
    }
  }

  // ── Supprimer une notification ───────────────────────────────────────────────
  Future<void> deleteNotification(String id) async {
    final wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
      unreadCount: wasUnread
          ? (state.unreadCount - 1).clamp(0, 999)
          : state.unreadCount,
    );

    try {
      await _api.dio.delete(ApiEndpoints.notificationDelete(id));
    } catch (_) {
      await fetchNotifications();
    }
  }

  // ── Incrémenter uniquement le badge (FCM sans données complètes) ─────────────
  void incrementUnread() {
    state = state.copyWith(unreadCount: state.unreadCount + 1);
  }

  // ── Helper ──────────────────────────────────────────────────────────────────
  int _countUnread(List<NotificationModel> list) =>
      list.where((n) => !n.isRead).length;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);

/// Badge count rapide (utilisé dans l'onglet et la nav bar)
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
