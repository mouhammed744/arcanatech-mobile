import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../models/user.dart';

class ThemeState {
  final Color primaryColor;
  final Color secondaryColor;
  final ThemeData theme;

  ThemeState({
    required this.primaryColor,
    required this.secondaryColor,
    required this.theme,
  });

  factory ThemeState.defaultTheme() => ThemeState(
        primaryColor: AppTheme.primary,
        secondaryColor: AppTheme.primaryLight,
        theme: AppTheme.buildTheme(),
      );
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState.defaultTheme());

  /// Applique le thème de l'université
  void applyUniversityTheme(University? university) {
    if (university == null) {
      state = ThemeState.defaultTheme();
      return;
    }

    final primary = AppTheme.hexToColor(university.primaryColor);
    final secondary = AppTheme.hexToColor(university.secondaryColor);

    state = ThemeState(
      primaryColor: primary,
      secondaryColor: secondary,
      theme: AppTheme.buildTheme(
        primaryColor: primary,
        secondaryColor: secondary,
      ),
    );
  }

  /// Reset au thème par défaut
  void reset() {
    state = ThemeState.defaultTheme();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
