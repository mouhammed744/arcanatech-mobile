import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/scanner_provider.dart';
import '../auth/qr_scanner_screen.dart';

// ─── Palette sombre exclusive au scanner ─────────────────────────────────────
const _kBg0      = Color(0xFF070B14); // fond quasi-noir
const _kBg1      = Color(0xFF0D1220); // fond secondaire
const _kBg2      = Color(0xFF111827); // fond card
const _kBlue     = Color(0xFF3B82F6);
const _kViolet   = Color(0xFF8B5CF6);
const _kCyan     = Color(0xFF06B6D4);
const _kGreen    = Color(0xFF10B981);
const _kOrange   = Color(0xFFF59E0B);
const _kRed      = Color(0xFFEF4444);

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseCtl;
  late AnimationController _rotateCtl;
  late AnimationController _rippleCtl;
  late AnimationController _sweepCtl;
  late AnimationController _glowCtl;
  late AnimationController _radarCtl;

  @override
  void initState() {
    super.initState();

    _pulseCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

    _rotateCtl = AnimationController(vsync: this,
        duration: const Duration(seconds: 8))..repeat();

    _rippleCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600))..repeat();

    _sweepCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat();

    _glowCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000))..repeat(reverse: true);

    _radarCtl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3200))..repeat();

    Future.microtask(() =>
        ref.read(scannerProvider.notifier).startScanning());
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    _rotateCtl.dispose();
    _rippleCtl.dispose();
    _sweepCtl.dispose();
    _glowCtl.dispose();
    _radarCtl.dispose();
    ref.read(scannerProvider.notifier).reset();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  Color _accentFor(ScanStatus s) {
    switch (s) {
      case ScanStatus.idle:
      case ScanStatus.scanning: return _kBlue;
      case ScanStatus.detected: return _kCyan;
      case ScanStatus.success:  return _kGreen;
      case ScanStatus.error:    return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerProvider);
    final accent    = _accentFor(scanState.status);
    final isActive  = scanState.status == ScanStatus.scanning ||
                      scanState.status == ScanStatus.idle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg0,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── Background: deep gradient ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.3),
                  radius: 1.3,
                  colors: [
                    accent.withValues(alpha: 0.10),
                    _kBg0,
                  ],
                ),
              ),
            ),

            // ── Dot grid texture ───────────────────────────────────────────
            CustomPaint(painter: _DotGridPainter()),

            // ── Orb top-right ──────────────────────────────────────────────
            Positioned(top: -60, right: -60,
              child: AnimatedBuilder(
                animation: _glowCtl,
                builder: (_, __) => Container(
                  width: 280, height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _kViolet.withValues(alpha: 0.10 + _glowCtl.value * 0.06),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // ── Orb bottom-left ────────────────────────────────────────────
            Positioned(bottom: -80, left: -60,
              child: AnimatedBuilder(
                animation: _glowCtl,
                builder: (_, __) => Container(
                  width: 320, height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _kBlue.withValues(alpha: 0.08 + _glowCtl.value * 0.05),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // ── Main content ───────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, scanState),
                  const SizedBox(height: 12),
                  Expanded(child: _buildScanZone(scanState, accent, isActive)),
                  _buildStatusLabel(scanState, accent),
                  const SizedBox(height: 20),
                  _buildBottomArea(scanState, accent),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildTopBar(BuildContext context, ScanResult state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [

          // ── Back button ──
          _GlassButton(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Iconsax.arrow_left_2, color: Colors.white, size: 20),
          ),

          const SizedBox(width: 14),

          // ── Title ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scanner RFID',
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.3,
                  ),
                ),
                Text('Pointage de présence',
                  style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),

          // ── Live badge ──
          _LiveBadge(controller: _pulseCtl, state: state),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.06);
  }

  // ═══════════════════════════════════════════════════════
  //  SCAN ZONE
  // ═══════════════════════════════════════════════════════
  Widget _buildScanZone(ScanResult state, Color accent, bool isActive) {
    return Center(
      child: SizedBox(
        width: 320, height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [

            // ── Ripple rings ──
            if (isActive) ...[
              _Ripple(controller: _rippleCtl, delay: 0.0,   size: 300, color: accent),
              _Ripple(controller: _rippleCtl, delay: 0.35,  size: 300, color: accent),
              _Ripple(controller: _rippleCtl, delay: 0.70,  size: 300, color: accent),
            ],

            // ── Radar sweep (only while scanning) ──
            if (isActive)
              AnimatedBuilder(
                animation: _radarCtl,
                builder: (_, __) => Transform.rotate(
                  angle: _radarCtl.value * 2 * pi,
                  child: CustomPaint(
                    size: const Size(260, 260),
                    painter: _RadarSweepPainter(accent),
                  ),
                ),
              ),

            // ── Rotating arc ring ──
            AnimatedBuilder(
              animation: _rotateCtl,
              builder: (_, child) => Transform.rotate(
                angle: _rotateCtl.value * 2 * pi,
                child: child,
              ),
              child: CustomPaint(
                size: const Size(250, 250),
                painter: _ArcRingPainter(accent),
              ),
            ),

            // ── Outer glow ring ──
            AnimatedBuilder(
              animation: _pulseCtl,
              builder: (_, __) => Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3 + _pulseCtl.value * 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.15 + _pulseCtl.value * 0.12),
                      blurRadius: 40, spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            // ── Glass circle ──
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 175, height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.06),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.15), width: 1,
                    ),
                  ),
                ),
              ),
            ),

            // ── Scan sweep line ──
            if (isActive)
              AnimatedBuilder(
                animation: _sweepCtl,
                builder: (_, __) {
                  final t = _sweepCtl.value;
                  final y = -80.0 + 160 * t;
                  return ClipOval(
                    child: SizedBox(
                      width: 175, height: 175,
                      child: Align(
                        alignment: Alignment(0, (y / 80).clamp(-1.0, 1.0)),
                        child: Container(
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                accent.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // ── Corner brackets ──
            ..._buildBrackets(accent),

            // ── Center icon / result ──
            _buildCenterIcon(state, accent),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 700.ms).scale(
      begin: const Offset(0.82, 0.82), curve: Curves.easeOutBack);
  }

  // ── 4 corner brackets ──────────────────────────────────────────────────────
  List<Widget> _buildBrackets(Color accent) {
    const r = 104.0; // radius from center
    const s = 22.0;  // arm length
    const t = 2.5;   // stroke width
    final positions = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];
    return positions.map((align) => Positioned(
      left:   align == Alignment.topLeft  || align == Alignment.bottomLeft  ? r - s : null,
      right:  align == Alignment.topRight || align == Alignment.bottomRight ? r - s : null,
      top:    align == Alignment.topLeft  || align == Alignment.topRight    ? r - s : null,
      bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight ? r - s : null,
      child: AnimatedBuilder(
        animation: _pulseCtl,
        builder: (_, __) => CustomPaint(
          size: const Size(s, s),
          painter: _BracketPainter(
            align: align,
            color: accent.withValues(alpha: 0.7 + _pulseCtl.value * 0.3),
            strokeWidth: t,
          ),
        ),
      ),
    )).toList();
  }

  // ═══════════════════════════════════════════════════════
  //  CENTER ICON
  // ═══════════════════════════════════════════════════════
  Widget _buildCenterIcon(ScanResult state, Color accent) {
    switch (state.status) {
      case ScanStatus.idle:
      case ScanStatus.scanning:
        return AnimatedBuilder(
          animation: _pulseCtl,
          builder: (_, child) => Opacity(
            opacity: 0.55 + _pulseCtl.value * 0.45,
            child: child,
          ),
          child: ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [Colors.white, accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(b),
            child: const Icon(Iconsax.wifi, size: 60, color: Colors.white),
          ),
        );

      case ScanStatus.detected:
        return SizedBox(
          width: 52, height: 52,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ).animate().fadeIn(duration: 300.ms);

      case ScanStatus.success:
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGreen.withValues(alpha: 0.12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.25),
                blurRadius: 30, spreadRadius: 4)],
          ),
          child: const Icon(Icons.check_rounded, size: 46, color: _kGreen),
        ).animate()
            .scale(begin: const Offset(0.3, 0.3), duration: 600.ms,
                curve: Curves.elasticOut)
            .fadeIn(duration: 300.ms);

      case ScanStatus.error:
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kRed.withValues(alpha: 0.12),
            border: Border.all(color: _kRed.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: _kRed.withValues(alpha: 0.25),
                blurRadius: 30, spreadRadius: 4)],
          ),
          child: const Icon(Icons.close_rounded, size: 46, color: _kRed),
        ).animate()
            .scale(begin: const Offset(0.3, 0.3), duration: 500.ms,
                curve: Curves.elasticOut)
            .shake(hz: 5, offset: const Offset(5, 0), duration: 500.ms);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  STATUS LABEL
  // ═══════════════════════════════════════════════════════
  Widget _buildStatusLabel(ScanResult state, Color accent) {
    late String title;
    late String sub;

    switch (state.status) {
      case ScanStatus.idle:
        title = 'Prêt à scanner'; sub = 'Approchez votre carte RFID';
      case ScanStatus.scanning:
        title = 'En attente…'; sub = 'Placez la carte près du capteur NFC';
      case ScanStatus.detected:
        title = 'Carte détectée'; sub = 'Vérification en cours…';
      case ScanStatus.success:
        final late = state.attendanceStatus == 'late';
        title = late ? 'Retard enregistré' : 'Présence validée !';
        sub   = state.message ?? '';
      case ScanStatus.error:
        title = 'Échec du scan'; sub = state.message ?? 'Veuillez réessayer';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: accent, letterSpacing: -0.5, height: 1.1,
            ),
            child: Text(title, textAlign: TextAlign.center,
              key: ValueKey('t_${state.status}')),
          ).animate(key: ValueKey('ta_${state.status}')).fadeIn(duration: 350.ms),
          const SizedBox(height: 8),
          Text(sub,
            textAlign: TextAlign.center,
            key: ValueKey('s_${state.status}'),
            style: GoogleFonts.inter(
              fontSize: 14, color: Colors.white38, height: 1.5,
            ),
          ).animate(key: ValueKey('sa_${state.status}')).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  BOTTOM AREA
  // ═══════════════════════════════════════════════════════
  Widget _buildBottomArea(ScanResult state, Color accent) {
    final isDone = state.status == ScanStatus.success ||
                   state.status == ScanStatus.error;

    if (!isDone) return _buildIdleFooter();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: _kBg1.withValues(alpha: 0.85),
              border: Border.all(
                color: accent.withValues(alpha: 0.18), width: 1,
              ),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.08),
                    blurRadius: 30, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Header strip ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(bottom: BorderSide(
                        color: accent.withValues(alpha: 0.12))),
                  ),
                  child: Row(children: [
                    Icon(
                      state.status == ScanStatus.success
                          ? Iconsax.tick_circle : Iconsax.warning_2,
                      size: 17,
                      color: accent.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      state.status == ScanStatus.success
                          ? 'Résultat du pointage' : 'Erreur de pointage',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: accent.withValues(alpha: 0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    _StatusPill(state: state, accent: accent),
                  ]),
                ),

                // ── Content ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: state.status == ScanStatus.success
                      ? _buildSuccessContent(state)
                      : _buildErrorContent(state),
                ),

                // ── Rescan button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _RescanButton(onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(scannerProvider.notifier).reset();
                    ref.read(scannerProvider.notifier).startScanning();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.10,
        curve: Curves.easeOutCubic);
  }

  Widget _buildSuccessContent(ScanResult state) {
    return Column(
      children: [
        _InfoRow(
          icon: Iconsax.book_1,
          label: 'Cours',
          value: state.courseName ?? '—',
          accent: _kBlue,
        ),
        _divider(),
        _InfoRow(
          icon: Iconsax.location,
          label: 'Salle',
          value: state.roomName ?? '—',
          accent: _kViolet,
        ),
        _divider(),
        _InfoRow(
          icon: Iconsax.clock,
          label: 'Heure',
          value: state.scanTime ?? '—',
          accent: _kCyan,
        ),
        _divider(),
        _InfoRow(
          icon: Iconsax.card,
          label: 'Carte',
          value: state.cardNumber ?? '—',
          accent: _kOrange,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildErrorContent(ScanResult state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kRed.withValues(alpha: 0.10),
            ),
            child: Icon(Iconsax.warning_2, color: _kRed.withValues(alpha: 0.8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              state.errorDetail ?? state.message ?? 'Carte non reconnue ou non autorisée.',
              style: GoogleFonts.inter(
                fontSize: 14, color: Colors.white60, height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.05)),
  );

  // ── Idle footer ─────────────────────────────────────────────────────────────
  Widget _buildIdleFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseCtl,
                builder: (_, __) => Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBlue,
                    boxShadow: [BoxShadow(
                      color: _kBlue.withValues(alpha: 0.4 + _pulseCtl.value * 0.4),
                      blurRadius: 10, spreadRadius: 2,
                    )],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Approchez la carte ou scannez le QR',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white24),
              ),
            ],
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 1400.ms),

          const SizedBox(height: 14),

          // ── Bouton scan QR → appelle le vrai backend ──
          _RescanButton(
            label: 'Scanner le QR de la carte',
            icon: Iconsax.scan,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QrScannerScreen(
                  onResult: (data) {
                    // Le QR contient le numéro de carte (clé 'card' ou 'matricule' ou brut)
                    final cardNumber = data['card'] ?? data['matricule'] ?? data['card_number'];
                    if (cardNumber != null && cardNumber.isNotEmpty) {
                      ref.read(scannerProvider.notifier).submitScan(cardNumber);
                    }
                  },
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _GlassButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _LiveBadge extends StatelessWidget {
  final AnimationController controller;
  final ScanResult state;
  const _LiveBadge({required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final isActive = state.status == ScanStatus.scanning ||
                     state.status == ScanStatus.idle;
    final color = isActive ? _kGreen : Colors.white38;
    final label = isActive ? 'LIVE' : 'PAUSE';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: controller,
                builder: (_, __) => Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [BoxShadow(
                      color: color.withValues(alpha: 0.3 + controller.value * 0.5),
                      blurRadius: 8, spreadRadius: 1,
                    )],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: Colors.white70, letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ScanResult state;
  final Color accent;
  const _StatusPill({required this.state, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isLate = state.attendanceStatus == 'late';
    final label  = state.status == ScanStatus.success
        ? (isLate ? 'RETARD' : 'PRÉSENT')
        : 'REFUSÉ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.15),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: accent, letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;
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
        child: Icon(icon, size: 16, color: accent.withValues(alpha: 0.8)),
      ),
      const SizedBox(width: 12),
      Text(label,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
      const Spacer(),
      Flexible(
        child: Text(value,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.87),
          ),
        ),
      ),
    ],
  );
}

class _RescanButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  const _RescanButton({
    required this.onTap,
    this.label = 'Scanner à nouveau',
    this.icon = Iconsax.refresh,
  });

  @override
  State<_RescanButton> createState() => _RescanButtonState();
}

class _RescanButtonState extends State<_RescanButton> {
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
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [_kBlue, _kViolet],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: _pressed ? 0.15 : 0.25),
              blurRadius: 20, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Text(widget.label,
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

/// Subtle dot grid
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Two rotating arcs
class _ArcRingPainter extends CustomPainter {
  final Color accent;
  _ArcRingPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final p1 = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final p2 = Paint()
      ..color = _kViolet.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final r1 = Rect.fromCircle(center: c, radius: r);
    final r2 = Rect.fromCircle(center: c, radius: r * 0.82);

    canvas.drawArc(r1, 0,          pi * 0.55, false, p1);
    canvas.drawArc(r1, pi,         pi * 0.55, false, p1);
    canvas.drawArc(r2, pi * 0.6,   pi * 0.40, false, p2);
    canvas.drawArc(r2, pi * 1.6,   pi * 0.40, false, p2);
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter old) => old.accent != accent;
}

/// Radar sweep gradient sector
class _RadarSweepPainter extends CustomPainter {
  final Color accent;
  _RadarSweepPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final shader = SweepGradient(
      startAngle: -pi / 2,
      endAngle:   pi / 2,
      colors: [
        Colors.transparent,
        accent.withValues(alpha: 0.0),
        accent.withValues(alpha: 0.12),
        accent.withValues(alpha: 0.06),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 0.85, 0.95, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    canvas.drawCircle(c, r, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter old) => old.accent != accent;
}

/// Ripple ring
class _Ripple extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;
  final Color  color;
  const _Ripple({required this.controller, required this.delay,
      required this.size, required this.color});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) {
      final p = ((controller.value + delay) % 1.0);
      return Opacity(
        opacity: (1.0 - p) * 0.18,
        child: Transform.scale(
          scale: 0.42 + p * 0.58,
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
            ),
          ),
        ),
      );
    },
  );
}

/// Corner bracket painter
class _BracketPainter extends CustomPainter {
  final Alignment align;
  final Color     color;
  final double    strokeWidth;
  _BracketPainter({required this.align, required this.color,
      required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final isLeft   = align == Alignment.topLeft  || align == Alignment.bottomLeft;
    final isTop    = align == Alignment.topLeft   || align == Alignment.topRight;
    final cx = isLeft ? 0.0 : s.width;
    final cy = isTop  ? 0.0 : s.height;
    final dx = isLeft ? s.width  : -s.width;
    final dy = isTop  ? s.height : -s.height;

    canvas.drawLine(Offset(cx, cy), Offset(cx + dx, cy), paint);
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy + dy), paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}
