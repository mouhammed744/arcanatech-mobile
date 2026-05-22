class TimetableEntry {
  final int id;
  final String courseName;
  final String? courseCode;
  final String startTime;
  final String endTime;
  final String? roomName;
  final String? teacherName;
  final int dayOfWeek; // 1=Lundi ... 6=Samedi
  final String? dayName;
  final String? date;

  const TimetableEntry({
    required this.id,
    required this.courseName,
    this.courseCode,
    required this.startTime,
    required this.endTime,
    this.roomName,
    this.teacherName,
    required this.dayOfWeek,
    this.dayName,
    this.date,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    final room = json['room'] as Map<String, dynamic>?;
    final classroom = json['classroom'] as Map<String, dynamic>?;
    final teacher = json['teacher'] as Map<String, dynamic>?;

    return TimetableEntry(
      id: json['id'] as int,
      courseName: course?['name'] as String? ??
          json['course_name'] as String? ??
          json['courseName'] as String? ??
          'Cours',
      courseCode: course?['code'] as String? ??
          json['course_code'] as String? ??
          json['courseCode'] as String?,
      startTime: json['startTime'] as String? ??
          json['start_time'] as String,
      endTime: json['endTime'] as String? ??
          json['end_time'] as String,
      roomName: classroom?['name'] as String? ??
          room?['name'] as String? ??
          json['room_name'] as String? ??
          json['roomName'] as String?,
      teacherName: teacher?['name'] as String? ??
          (teacher != null
              ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim()
              : json['teacher_name'] as String? ??
                json['teacherName'] as String?),
      dayOfWeek: json['dayOfWeek'] as int? ??
          json['day_of_week'] as int? ??
          1,
      dayName: json['dayName'] as String? ??
          json['day_name'] as String?,
      date: json['date'] as String?,
    );
  }

  String get dayLabel {
    if (dayName != null && dayName!.isNotEmpty) return dayName!;
    const days = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    return (dayOfWeek >= 1 && dayOfWeek <= 6) ? days[dayOfWeek] : '';
  }

  String get timeRange => '$startTime - $endTime';
}
