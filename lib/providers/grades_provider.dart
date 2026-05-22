import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../models/grade.dart';
import 'auth_provider.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class GradesState {
  final List<Grade> grades;
  final bool isLoading;
  final String? error;
  final String semester;

  const GradesState({
    this.grades = const [],
    this.isLoading = false,
    this.error,
    this.semester = 'S5',
  });

  // ── Calculs agrégés ──
  double get average {
    if (grades.isEmpty) return 0;
    double totalWeight = 0;
    double totalScore = 0;
    for (final g in grades) {
      totalScore += g.note * g.coefficient;
      totalWeight += g.coefficient;
    }
    return totalWeight > 0 ? totalScore / totalWeight : 0;
  }

  int get totalECTS => grades.fold(0, (sum, g) => sum + g.ects);
  int get validatedECTS =>
      grades.where((g) => g.isValidated).fold(0, (sum, g) => sum + g.ects);
  int get totalXP => grades.fold(0, (sum, g) => sum + g.xp);

  String get levelTitle {
    final avg = average;
    if (avg >= 16) return 'Maître';
    if (avg >= 14) return 'Expert';
    if (avg >= 12) return 'Avancé';
    if (avg >= 10) return 'Confirmé';
    return 'Novice';
  }

  int get levelNumber {
    final avg = average;
    if (avg >= 16) return 4;
    if (avg >= 14) return 3;
    if (avg >= 12) return 2;
    if (avg >= 10) return 1;
    return 0;
  }

  double get nextLevelProgress {
    final avg = average;
    if (avg >= 16) return 1.0;
    if (avg >= 14) return ((avg - 14) / 2).clamp(0.0, 1.0);
    if (avg >= 12) return ((avg - 12) / 2).clamp(0.0, 1.0);
    if (avg >= 10) return ((avg - 10) / 2).clamp(0.0, 1.0);
    return (avg / 10).clamp(0.0, 1.0);
  }

  String get nextLevelTitle {
    switch (levelNumber) {
      case 0:  return 'Confirmé';
      case 1:  return 'Avancé';
      case 2:  return 'Expert';
      case 3:  return 'Maître';
      default: return '—';
    }
  }

  GradesState copyWith({
    List<Grade>? grades,
    bool? isLoading,
    String? error,
    String? semester,
    bool clearError = false,
  }) =>
      GradesState(
        grades:    grades    ?? this.grades,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
        semester:  semester  ?? this.semester,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class GradesNotifier extends StateNotifier<GradesState> {
  final Ref _ref;
  GradesNotifier(this._ref) : super(const GradesState());

  Future<void> loadGrades({String? semester}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = _ref.read(authProvider).user;
      if (user == null) throw Exception('Non authentifié');

      final api = ApiClient();
      final response = await api.dio.get(
        '/students/${user.id}/grades',
        queryParameters: {'semester': semester ?? state.semester},
      );

      final data = response.data;
      List<Grade> grades = [];
      if (data is List) {
        grades = data
            .map((e) => Grade.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data['data'] is List) {
        grades = (data['data'] as List)
            .map((e) => Grade.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      state = state.copyWith(isLoading: false, grades: grades);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        grades: const [],
        error: 'Impossible de charger vos notes.',
      );
    }
  }
}

final gradesProvider = StateNotifierProvider<GradesNotifier, GradesState>(
  (ref) => GradesNotifier(ref),
);
