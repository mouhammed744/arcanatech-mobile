import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/attendance.dart';
import 'auth_provider.dart';

class AttendanceState {
  final List<Attendance> records;
  final bool isLoading;
  final String? error;
  final String filter; // 'all', 'present', 'late', 'absent'

  const AttendanceState({
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.filter = 'all',
  });

  List<Attendance> get filteredRecords {
    if (filter == 'all') return records;
    return records.where((r) => r.status == filter).toList();
  }

  /// Stats globales
  int get totalPresent => records.where((r) => r.isPresent).length;
  int get totalLate => records.where((r) => r.isLate).length;
  int get totalAbsent => records.where((r) => r.isAbsent).length;

  double get presenceRate {
    if (records.isEmpty) return 0;
    return (totalPresent + totalLate) / records.length * 100;
  }

  AttendanceState copyWith({
    List<Attendance>? records,
    bool? isLoading,
    String? error,
    String? filter,
    bool clearError = false,
  }) =>
      AttendanceState(
        records: records ?? this.records,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        filter: filter ?? this.filter,
      );
}


class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref ref;
  final _api = ApiClient();

  AttendanceNotifier(this.ref) : super(const AttendanceState());

  Future<void> loadAttendances() async {
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
        ApiEndpoints.studentAttendances(user.universityId!, user.studentId!),
      );

      final data = response.data is Map
          ? (response.data['data'] as List? ??
              response.data['attendances'] as List? ?? [])
          : (response.data as List? ?? []);

      final records = data
          .map((json) => Attendance.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(records: records, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        records: const [],
        isLoading: false,
        error: 'Impossible de charger vos présences.',
      );
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>(
  (ref) => AttendanceNotifier(ref),
);
