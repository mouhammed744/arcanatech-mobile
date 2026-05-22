import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'auth_provider.dart';

enum ScanStatus {
  idle,       // En attente, prêt à scanner
  scanning,   // NFC actif, recherche de carte
  detected,   // Carte détectée, envoi au serveur
  success,    // Présence enregistrée
  error,      // Erreur (carte inconnue, déjà scanné, etc.)
}

class ScanResult {
  final ScanStatus status;
  final String? cardNumber;
  final String? courseName;
  final String? roomName;
  final String? attendanceStatus; // 'present', 'late'
  final String? scanTime;
  final String? message;
  final String? errorDetail;

  const ScanResult({
    this.status = ScanStatus.idle,
    this.cardNumber,
    this.courseName,
    this.roomName,
    this.attendanceStatus,
    this.scanTime,
    this.message,
    this.errorDetail,
  });

  ScanResult copyWith({
    ScanStatus? status,
    String? cardNumber,
    String? courseName,
    String? roomName,
    String? attendanceStatus,
    String? scanTime,
    String? message,
    String? errorDetail,
    bool clearError = false,
  }) =>
      ScanResult(
        status: status ?? this.status,
        cardNumber: cardNumber ?? this.cardNumber,
        courseName: courseName ?? this.courseName,
        roomName: roomName ?? this.roomName,
        attendanceStatus: attendanceStatus ?? this.attendanceStatus,
        scanTime: scanTime ?? this.scanTime,
        message: message ?? this.message,
        errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      );
}

class ScannerNotifier extends StateNotifier<ScanResult> {
  final Ref ref;
  final _api = ApiClient();
  Timer? _demoTimer;

  ScannerNotifier(this.ref) : super(const ScanResult());

  /// Démarre l'attente de scan NFC.
  /// Sur téléphone physique : le QR scanner (qr_scanner_screen) lit la carte
  /// et appelle submitScan(). Cette méthode met simplement l'état en attente.
  Future<void> startScanning() async {
    state = const ScanResult(status: ScanStatus.scanning);
  }

  /// Envoie le scan au backend
  /// Réponse backend : { status, message, course: {name}, classroom: {name}, attendance: {scanned_at} }
  Future<void> submitScan(String cardNumber) async {
    final user = ref.read(authProvider).user;
    if (user?.universityId == null) return;

    state = state.copyWith(status: ScanStatus.detected, message: 'Vérification...');

    try {
      final response = await _api.dio.post(
        ApiEndpoints.rfidScan(user!.universityId!),
        data: {'card_number': cardNumber},
      );

      final data = response.data as Map<String, dynamic>;

      // Le backend renvoie des objets imbriqués : course.name, classroom.name, attendance.scanned_at
      final course    = data['course']    as Map<String, dynamic>?;
      final classroom = data['classroom'] as Map<String, dynamic>?;
      final attendance = data['attendance'] as Map<String, dynamic>?;

      // Format heure depuis ISO8601 → "HH:mm"
      final rawTime = attendance?['scanned_at'] as String?;
      String? scanTime;
      if (rawTime != null) {
        try {
          final dt = DateTime.parse(rawTime).toLocal();
          scanTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          scanTime = rawTime;
        }
      }

      state = ScanResult(
        status: ScanStatus.success,
        cardNumber: cardNumber,
        courseName: course?['name'] as String?,
        roomName: classroom?['name'] as String?,
        attendanceStatus: data['status'] as String?,
        scanTime: scanTime,
        message: data['message'] as String? ?? 'Présence enregistrée',
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message'] as String?
          : null;
      state = ScanResult(
        status: ScanStatus.error,
        cardNumber: cardNumber,
        errorDetail: msg ?? 'Carte non reconnue ou accès refusé',
        message: msg ?? 'Erreur lors du scan',
      );
    } catch (_) {
      state = ScanResult(
        status: ScanStatus.error,
        cardNumber: cardNumber,
        errorDetail: 'Impossible de valider le scan',
        message: 'Erreur de connexion au serveur',
      );
    }
  }

  /// Simule une erreur de scan (pour la démo)
  void simulateError() {
    state = const ScanResult(
      status: ScanStatus.error,
      cardNumber: 'RFID-XXXX-XXXX',
      message: 'Carte non reconnue',
      errorDetail: 'Cette carte n\'est pas associée à un étudiant',
    );
  }

  /// Reset pour un nouveau scan
  void reset() {
    _demoTimer?.cancel();
    state = const ScanResult();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }
}

final scannerProvider = StateNotifierProvider<ScannerNotifier, ScanResult>(
  (ref) => ScannerNotifier(ref),
);
