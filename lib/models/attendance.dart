class Attendance {
  final int id;
  final String status; // 'present', 'late', 'absent'
  final String? scanTime;
  final String date;
  final String? courseName;
  final int? courseId;
  final String? courseCode;
  final String? sessionStart;
  final String? sessionEnd;
  final String? roomName;
  final String? notes;
  final String? verificationMethod;

  const Attendance({
    required this.id,
    required this.status,
    this.scanTime,
    required this.date,
    this.courseName,
    this.courseId,
    this.courseCode,
    this.sessionStart,
    this.sessionEnd,
    this.roomName,
    this.notes,
    this.verificationMethod,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    // Support nested course object from new API
    final course = json['course'] as Map<String, dynamic>?;
    // Support nested timetable object from new API
    final timetable = json['timetable'] as Map<String, dynamic>?;
    // Support legacy nested session object
    final session = json['session'] as Map<String, dynamic>?;

    return Attendance(
      id: json['id'] as int,
      status: json['status'] as String,
      scanTime: json['scanned_at'] as String? ??
          json['scan_time'] as String?,
      date: json['scanned_at'] as String? ??
          json['date'] as String? ??
          json['created_at'] as String? ??
          '',
      courseName: course?['name'] as String? ??
          json['course_name'] as String? ??
          (session is Map<String, dynamic> && session['course'] is Map
              ? (session['course'] as Map)['name'] as String?
              : null),
      courseId: course?['id'] as int? ??
          json['course_id'] as int? ??
          (session is Map<String, dynamic> ? session['course_id'] as int? : null),
      courseCode: course?['code'] as String?,
      sessionStart: timetable?['start_time'] as String? ??
          json['session_start'] as String? ??
          (session is Map<String, dynamic> ? session['start_time'] as String? : null),
      sessionEnd: timetable?['end_time'] as String? ??
          json['session_end'] as String? ??
          (session is Map<String, dynamic> ? session['end_time'] as String? : null),
      roomName: timetable?['classroom'] as String? ??
          json['room_name'] as String? ??
          (session is Map<String, dynamic> && session['room'] is Map
              ? (session['room'] as Map)['name'] as String?
              : null),
      notes: json['notes'] as String?,
      verificationMethod: json['verification_method'] as String? ??
          json['verificationMethod'] as String?,
    );
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'Pr\u00e9sent';
      case 'late':
        return 'Retard';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }
}
