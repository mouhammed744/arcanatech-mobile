import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/timetable_entry.dart';
import 'auth_provider.dart';


class ScheduleState {
  final List<TimetableEntry> entries;
  final bool isLoading;
  final String? error;

  const ScheduleState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  /// Filtre les cours par jour de la semaine
  List<TimetableEntry> forDay(int dayOfWeek) =>
      entries.where((e) => e.dayOfWeek == dayOfWeek).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  ScheduleState copyWith({
    List<TimetableEntry>? entries,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ScheduleState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final Ref ref;
  final _api = ApiClient();

  ScheduleNotifier(this.ref) : super(const ScheduleState());

  Future<void> loadSchedule() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (user.universityId == null || user.studentId == null) {
        // Compte étudiant incomplet (filière non encore assignée)
        state = state.copyWith(
          entries: const [],
          isLoading: false,
          error: 'Votre filière n\'est pas encore configurée. Contactez l\'administration.',
        );
        return;
      }

      final response = await _api.dio.get(
        ApiEndpoints.studentTimetable(user.universityId!, user.studentId!),
      );

      final data = response.data is Map
          ? (response.data['data'] as List? ??
              response.data['timetable'] as List? ??
              [])
          : (response.data as List? ?? []);

      final entries = (data as List)
          .map((json) => TimetableEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      // Affiche les vrais cours — ou liste vide si l'admin n'a encore rien programmé
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      // Erreur réseau : on laisse les entrées existantes et on signale l'erreur
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger l\'emploi du temps. Vérifiez votre connexion.',
      );
    }
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>(
  (ref) => ScheduleNotifier(ref),
);
