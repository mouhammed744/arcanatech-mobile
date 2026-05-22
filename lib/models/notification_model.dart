import 'dart:convert';

class NotificationModel {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  String get title => (data['title'] as String?) ?? _titleFromType(type);
  String get body  => (data['body']  as String?) ?? '';
  String get notifType => (data['type'] as String?) ?? type;

  // ── Titre par défaut selon le type FCM ───────────────────────────────────────
  static String _titleFromType(String t) {
    switch (t) {
      case 'schedule_created': return 'Emploi du temps mis à jour';
      case 'schedule_updated': return 'Séance modifiée';
      case 'schedule_deleted': return 'Séance supprimée';
      default:                 return 'Notification';
    }
  }

  Map<String, dynamic>? get payload {
    final p = data['payload'];
    if (p is Map<String, dynamic>) return p;
    return null;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedData = {};
    final raw = json['data'];

    if (raw is Map<String, dynamic>) {
      parsedData = raw;
    } else if (raw is String && raw.isNotEmpty) {
      // Laravel stocke parfois le JSON encodé en string — décoder correctement
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) parsedData = decoded;
      } catch (_) {}
    }

    return NotificationModel(
      id:        json['id'] as String,
      type:      (json['type'] as String?) ?? '',
      data:      parsedData,
      readAt:    json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Créer depuis les données FCM (message foreground/background)
  factory NotificationModel.fromFcm(Map<String, dynamic> fcmData) {
    return NotificationModel(
      id:        'fcm-${DateTime.now().millisecondsSinceEpoch}',
      type:      fcmData['type'] as String? ?? 'schedule',
      data:      Map<String, dynamic>.from(fcmData),
      createdAt: DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id:        id,
      type:      type,
      data:      data,
      readAt:    isRead == true ? DateTime.now() : readAt,
      createdAt: createdAt,
    );
  }
}
