import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dual-Mode du concept "Dual-Mode Fluidity"
/// Focus  → Cours, notes, emploi du temps (cyan/violet, formes géométriques)
/// Campus → Événements, chat, clubs     (coral/orange, formes organiques)
enum AppMode { focus, campus }

class ModeState {
  final AppMode mode;

  const ModeState({this.mode = AppMode.focus});

  bool get isFocus => mode == AppMode.focus;
  bool get isCampus => mode == AppMode.campus;

  ModeState copyWith({AppMode? mode}) =>
      ModeState(mode: mode ?? this.mode);
}

class ModeNotifier extends StateNotifier<ModeState> {
  ModeNotifier() : super(const ModeState());

  void toggle() {
    HapticFeedback.heavyImpact();
    state = ModeState(
      mode: state.isFocus ? AppMode.campus : AppMode.focus,
    );
  }

  void setFocus() {
    if (state.isFocus) return;
    HapticFeedback.mediumImpact();
    state = const ModeState(mode: AppMode.focus);
  }

  void setCampus() {
    if (state.isCampus) return;
    HapticFeedback.mediumImpact();
    state = const ModeState(mode: AppMode.campus);
  }
}

final modeProvider = StateNotifierProvider<ModeNotifier, ModeState>(
  (ref) => ModeNotifier(),
);
