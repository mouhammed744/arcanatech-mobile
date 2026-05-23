import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/scanner_provider.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF3B82F6);
const _kViolet = Color(0xFF8B5CF6);
const _kCyan   = Color(0xFF06B6D4);
const _kGreen  = Color(0xFF10B981);
const _kOrange = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);

// ─────────────────────────────────────────────────────────────────────────────
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {

  // ── Caméra ──
  late final MobileScannerController _cam;
  bool _torch    = false;
  bool _scanned  = false; // verrou anti-doublons

  // ── Animations ──
  late AnimationController _lineCtl;   // ligne de scan
  late AnimationController _pulseCtl;  // pulsation coins
  late AnimationController _rotCtl;    // arc rotatif

  @override
  void initState() {
    super.initState();

    _cam = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _lineCtl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _pulseCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _rotCtl   = AnimationController(vsync: this,
        duration: const Duration(seconds: 6))..repeat();

    // réinitialiser l'état scanner
    ref.read(scannerProvider.notifier).reset();
  }

  @override
  void dispose() {
    _cam.dispose();
    _lineCtl.dispose();
    _pulseCtl.dispose();
    _rotCtl.dispose();
    ref.read(scannerProvider.notifier).reset();
    super.dispose();
  }

  // ── Détection QR ──────────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _scanned = true;
    HapticFeedback.mediumImpact();
    _cam.stop();

    // Parser le contenu du QR
    final cardNumber = _parseCardNumber(raw);
    ref.read(scannerProvider.notifier).submitScan(cardNumber);
  }

  /// Extrait le numéro de carte depuis le QR brut.
  /// Formats supportés :
  ///   - "card=XXXX;..." ou "card_number=XXXX;..."
  ///   - "matricule=XXXX;..."
  ///   - brut : "XXXX"
  String _parseCardNumber(String raw) {
    final pairs = raw.split(RegExp(r'[;|&]'));
    for (final pair in pairs) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final key = pair.substring(0, idx).trim().toLowerCase();
      final val = pair.substring(idx + 1).trim();
      if (['card', 'card_number', 'matricule', 'rfid'].contains(key)) {
        return val;
      }
    }
    return raw.trim();
  }

  void _reset() {
    setState(() => _scanned = false);
    ref.read(scannerProvider.notifier).reset();
    _cam.start();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerProvider);
    final size      = MediaQuery.of(context).size;
    final frameW    = size.width * 0.72;
    final isDone    = scanState.status == ScanStatus.success ||
                      scanState.status == ScanStatus.error;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── 1. FLUX CAMÉRA ──────────────────────────────────────────
            if (!isDone)
              MobileScanner(
                controller: _cam,
                onDetect: _onDetect,
              )
            else
              // Fond sombre quand résultat affiché
              Container(color: const Color(0xFF070B14)),

            // ── 2. OVERLAY SOMBRE avec découpe centrale ──────────────────
            if (!isDone) _buildDimOverlay(size, frameW),

            // ── 3. CADRE ANIMÉ (coins + arc rotatif + ligne de scan) ─────
            if (!isDone)
              Center(
                child: SizedBox(
                  width: frameW, height: frameW,
                  child: Stack(
                    children: [
                      // Arc rotatif
                      AnimatedBuilder(
                        animation: _rotCtl,
                        builder: (_, __) => Transform.rotate(
                          angle: _rotCtl.value * 2 * pi,
                          child: CustomPaint(
                            size: Size(frameW, frameW),
                            painter: _ArcPainter(_kBlue),
                          ),
                        ),
                      ),
                      // Coins animés
                      AnimatedBuilder(
                        animation: _pulseCtl,
                        builder: (_, __) => CustomPaint(
                          size: Size(frameW, frameW),
                          painter: _CornerPainter(
                            color: _kBlue.withValues(
                                alpha: 0.7 + _pulseCtl.value * 0.3),
                          ),
                        ),
                      ),
                      // Ligne de scan
                      AnimatedBuilder(
                        animation: _lineCtl,
                        builder: (_, __) => Positioned(
                          top: frameW * _lineCtl.value,
                          left: 12, right: 12,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _kCyan,
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: _kCyan.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 4. ÉTAT : DÉTECTION EN COURS ────────────────────────────
            if (scanState.status == ScanStatus.detected)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 52, height: 52,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _kCyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Vérification…',
                      style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ),

            // ── 5. CARTE RÉSULTAT (succès / erreur) ──────────────────────
            if (isDone)
              Positioned(
                left: 0, right: 0,
                top: MediaQuery.of(context).padding.top + 60,
                bottom: 0,
                child: _ResultCard(
                  state: scanState,
                  onRescan: _reset,
                  onClose: () => Navigator.of(context).pop(),
                ).animate().fadeIn(duration: 400.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOutCubic),
              ),

            // ── 6. TOP BAR ───────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _CtrlBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      isDone ? 'Résultat du scan' : 'Scanner QR / Code-barre',
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (!isDone)
                      _CtrlBtn(
                        icon: _torch
                            ? Icons.flashlight_off_rounded
                            : Icons.flashlight_on_rounded,
                        onTap: () {
                          setState(() => _torch = !_torch);
                          _cam.toggleTorch();
                        },
                      )
                    else
                      const SizedBox(width: 42),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),
            ),

            // ── 7. GUIDE TEXTE (pendant scan) ───────────────────────────
            if (!isDone && scanState.status != ScanStatus.detected)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 48,
                left: 24, right: 24,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Text(
                        'Centrez le QR ou code-barres dans le cadre',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 1400.ms),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Overlay sombre avec fenêtre centrale ──────────────────────────────────
  Widget _buildDimOverlay(Size size, double frameW) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.transparent,
        BlendMode.dstOut,
      ),
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.62)),
          Center(
            child: Container(
              width: frameW,
              height: frameW,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte de résultat ────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final ScanResult state;
  final VoidCallback onRescan;
  final VoidCallback onClose;

  const _ResultCard({
    required this.state,
    required this.onRescan,
    required this.onClose,
  });

  Color get _accent => state.status == ScanStatus.success ? _kGreen : _kRed;

  @override
  Widget build(BuildContext context) {
    final isSuccess = state.status == ScanStatus.success;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF0D1220).withValues(alpha: 0.92),
              border: Border.all(
                  color: _accent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.12),
                  blurRadius: 40, spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icône résultat ──
                const SizedBox(height: 32),
                _buildResultIcon(isSuccess),
                const SizedBox(height: 20),

                // ── Titre & message ──
                Text(
                  isSuccess
                      ? (state.attendanceStatus == 'late'
                          ? 'Retard enregistré'
                          : 'Présence validée !')
                      : 'Scan refusé',
                  style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: _accent, letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.message ?? (isSuccess ? 'Présence enregistrée' : 'Carte non reconnue'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.white38, height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Détails (si succès) ──
                if (isSuccess) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _InfoRow(
                            icon: Iconsax.book_1,
                            label: 'Cours',
                            value: state.courseName ?? '—',
                            accent: _kBlue),
                        _divider(),
                        _InfoRow(
                            icon: Iconsax.location,
                            label: 'Salle',
                            value: state.roomName ?? '—',
                            accent: _kViolet),
                        _divider(),
                        _InfoRow(
                            icon: Iconsax.clock,
                            label: 'Heure',
                            value: state.scanTime ?? '—',
                            accent: _kCyan),
                        _divider(),
                        _InfoRow(
                            icon: Iconsax.card,
                            label: 'Carte',
                            value: state.cardNumber ?? '—',
                            accent: _kOrange),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _kRed.withValues(alpha: 0.08),
                        border: Border.all(
                            color: _kRed.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        state.errorDetail ?? 'Cette carte n\'est pas autorisée.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white54, height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Boutons ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Row(
                    children: [
                      // Fermer
                      Expanded(
                        child: _OutlineBtn(
                          label: 'Fermer',
                          icon: Icons.close_rounded,
                          onTap: onClose,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Scanner à nouveau
                      Expanded(
                        flex: 2,
                        child: _GradientBtn(
                          label: 'Scanner à nouveau',
                          icon: Iconsax.scan,
                          onTap: onRescan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultIcon(bool isSuccess) {
    return Container(
      width: 88, height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accent.withValues(alpha: 0.10),
        border: Border.all(color: _accent.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.20),
              blurRadius: 30, spreadRadius: 4),
        ],
      ),
      child: Icon(
        isSuccess ? Icons.check_rounded : Icons.close_rounded,
        size: 48, color: _accent,
      ),
    ).animate()
        .scale(begin: const Offset(0.3, 0.3), duration: 600.ms,
            curve: Curves.elasticOut)
        .fadeIn(duration: 300.ms);
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    height: 0.5,
    color: Colors.white.withValues(alpha: 0.06),
  );
}

// ─── Widgets partagés ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color accent;
  const _InfoRow({required this.icon, required this.label,
      required this.value, required this.accent});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: accent.withValues(alpha: 0.12),
        ),
        child: Icon(icon, size: 16, color: accent.withValues(alpha: 0.85)),
      ),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
      const Spacer(),
      Flexible(
        child: Text(value,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.87),
          )),
      ),
    ],
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _GradientBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientBtn({required this.label, required this.icon, required this.onTap});

  @override
  State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [_kBlue, _kViolet],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: _pressed ? 0.12 : 0.25),
              blurRadius: 16, offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(widget.label,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
              )),
          ],
        ),
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: Colors.white54),
          const SizedBox(width: 8),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: Colors.white54,
            )),
        ],
      ),
    ),
  );
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Quatre coins arrondis du cadre
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r   = 18.0;

    // Top-left
    canvas.drawPath(Path()
      ..moveTo(0, len + r)
      ..arcToPoint(const Offset(r, r), radius: const Radius.circular(r))
      ..lineTo(len + r, r), p);
    // Top-right
    canvas.drawPath(Path()
      ..moveTo(size.width - len - r, r)
      ..lineTo(size.width - r, r)
      ..arcToPoint(Offset(size.width, r + r), radius: const Radius.circular(r))
      ..lineTo(size.width, r + len + r), p);
    // Bottom-right
    canvas.drawPath(Path()
      ..moveTo(size.width, size.height - len - r)
      ..arcToPoint(Offset(size.width - r, size.height - r),
          radius: const Radius.circular(r))
      ..lineTo(size.width - len - r, size.height - r), p);
    // Bottom-left
    canvas.drawPath(Path()
      ..moveTo(len + r, size.height - r)
      ..lineTo(r, size.height - r)
      ..arcToPoint(Offset(0, size.height - r - r),
          radius: const Radius.circular(r))
      ..lineTo(0, size.height - r - len - r), p);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

/// Deux arcs rotatifs décoratifs
class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final p1 = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        0, pi * 0.5, false, p1);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        pi, pi * 0.5, false, p1);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.88),
        pi * 0.6, pi * 0.35, false,
        p1..color = _kViolet.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
