import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/attendance.dart';
import '../models/rfid_card.dart';
import 'auth_provider.dart';

class StudentStats {
  final double presenceRate;
  final int lateCount;
  final int absentCount;
  final int totalSessions;
  final List<Attendance> recentAttendances;
  final RfidCard? rfidCard;

  const StudentStats({
    this.presenceRate = 0,
    this.lateCount = 0,
    this.absentCount = 0,
    this.totalSessions = 0,
    this.recentAttendances = const [],
    this.rfidCard,
  });
}

class StudentState {
  final StudentStats? stats;
  final bool isLoading;
  final String? error;

  const StudentState({this.stats, this.isLoading = false, this.error});

  StudentState copyWith({
    StudentStats? stats,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      StudentState(
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class StudentNotifier extends StateNotifier<StudentState> {
  final Ref ref;
  final _api = ApiClient();

  StudentNotifier(this.ref) : super(const StudentState());

  Future<void> loadStats() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (user.universityId == null || user.studentId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Compte étudiant non configuré. '
              'Contactez votre établissement.',
        );
        return;
      }

      final response = await _api.dio.get(
        ApiEndpoints.studentDetail(user.universityId!, user.studentId!),
      );

      final data = response.data is Map
          ? (response.data['student'] ?? response.data)
          : response.data;

      final statsData =
          (data['overall_statistics'] ?? data['stats'])
              as Map<String, dynamic>? ??
              {};
      final rfidData = data['rfid_card'] as Map<String, dynamic>?;

      final recentData = data['recent_attendances'] as List? ?? [];
      final recent = recentData
          .map((json) => Attendance.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        stats: StudentStats(
          presenceRate: ((statsData['overall_attendance_rate'] ??
                      statsData['presence_rate']) as num?)
                  ?.toDouble() ??
              0,
          lateCount    : (statsData['late_count']   as int?) ?? 0,
          absentCount  : (statsData['absent_count'] as int?) ?? 0,
          totalSessions: ((statsData['total_sessions_attended'] ??
                  statsData['total_sessions']) as int?) ?? 0,
          recentAttendances: recent,
          rfidCard: rfidData != null ? RfidCard.fromJson(rfidData) : null,
        ),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger vos statistiques.',
      );
    }
  }
}

final studentProvider =
    StateNotifierProvider<StudentNotifier, StudentState>(
  (ref) => StudentNotifier(ref),
);
