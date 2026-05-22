import 'package:flutter/material.dart';

/// Modèle d'une note / matière universitaire
class Grade {
  final int id;
  final String courseName;
  final String courseCode;
  final double note; // /20
  final double coefficient;
  final int ects;
  final String semester;
  final Color color;

  const Grade({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.note,
    required this.coefficient,
    required this.ects,
    required this.semester,
    required this.color,
  });

  bool get isValidated => note >= 10.0;

  double get percentage => (note / 20.0).clamp(0.0, 1.0);

  String get mention {
    if (note >= 16) return 'Très Bien';
    if (note >= 14) return 'Bien';
    if (note >= 12) return 'Assez Bien';
    if (note >= 10) return 'Passable';
    return 'Insuffisant';
  }

  String get shortMention {
    if (note >= 16) return 'TB';
    if (note >= 14) return 'B';
    if (note >= 12) return 'AB';
    if (note >= 10) return 'P';
    return '—';
  }

  /// XP points pour l'écran gamifié
  int get xp => (note * coefficient * 10).round();

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] as int,
      courseName: json['courseName'] as String? ??
          json['course_name'] as String? ??
          'Cours',
      courseCode: json['courseCode'] as String? ??
          json['course_code'] as String? ??
          '',
      note: (json['note'] as num?)?.toDouble() ?? 0.0,
      coefficient: (json['coefficient'] as num?)?.toDouble() ?? 1.0,
      ects: json['ects'] as int? ?? 3,
      semester: json['semester'] as String? ?? 'S1',
      color: Color(json['color'] as int? ?? 0xFF00D4FF),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'courseCode': courseCode,
        'note': note,
        'coefficient': coefficient,
        'ects': ects,
        'semester': semester,
        'color': color.toARGB32(),
      };
}
