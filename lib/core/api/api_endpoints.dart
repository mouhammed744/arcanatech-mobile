class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth (public) ──
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String registerStudent = '/auth/register-student';
  static const String refresh = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String twoFactorChallenge = '/auth/2fa/verify';

  // ── Auth (protected) ──
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String avatar = '/auth/avatar';
  static const String changePassword = '/auth/change-password';

  // ── Universities (public) ──
  static const String universities = '/universities';

  // ── Students ──
  static String studentDetail(int universityId, int studentId) =>
      '/universities/$universityId/students/$studentId';

  static String studentAttendances(int universityId, int studentId) =>
      '/universities/$universityId/students/$studentId/attendances';

  static String studentTimetable(int universityId, int studentId) =>
      '/universities/$universityId/students/$studentId/timetable';

  // ── Courses ──
  static String courses(int universityId) =>
      '/universities/$universityId/courses';

  static String courseDetail(int universityId, int courseId) =>
      '/universities/$universityId/courses/$courseId';

  // ── Filières ──
  static String filieres(int universityId) =>
      '/universities/$universityId/filieres';

  // ── Filières publiques (inscription — pas d'auth) ──
  static String filieresPublic(int universityId) =>
      '/universities/$universityId/filieres-public';

  // ── Attendances ──
  static String attendances(int universityId) =>
      '/universities/$universityId/attendances';

  // ── Emploi du temps (filière) ──
  static String filiereTimetable(int universityId, int filiereId) =>
      '/universities/$universityId/filieres/$filiereId/timetable';

  // ── Scanner RFID ──
  static String rfidScan(int universityId) =>
      '/universities/$universityId/rfid/scan';

  static String rfidVerify(int universityId) =>
      '/universities/$universityId/rfid/verify';

  // ── Notifications ──
  static const String notifications        = '/me/notifications';
  static const String notificationsReadAll = '/me/notifications/read-all';
  static String notificationRead(String id) => '/me/notifications/$id/read';
  static String notificationDelete(String id) => '/me/notifications/$id';

  // ── FCM Token ──
  static const String fcmToken = '/me/fcm-token';

  // ── OAuth Social Login ──
  static const String socialLogin = '/auth/social/login';
}
