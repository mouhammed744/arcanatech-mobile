import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';

// ─── Palette dark splash (indépendant du thème clair de l'app) ─────────────
const _kBg       = Color(0xFF04040F);
const _kBlue     = Color(0xFF2563EB);
const _kCyan     = Color(0xFF06B6D4);
const _kViolet   = Color(0xFF7C3AED);
const _kOrange   = Color(0xFFF97316);
const _kWhite    = Colors.white;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _ring1;   // outer ring — slow
  late final AnimationController _ring2;   // middle ring — medium
  late final AnimationController _ring3;   // inner ring — fast
  late final AnimationController _pulse;   // glow pulse
  late final AnimationController _orbit;   // particles orbit
  late final AnimationController _float;   // logo subtle float
  late final AnimationController _bar;     // loading bar

  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _ring1  = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _ring2  = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _ring3  = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: false);
    _pulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _orbit  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    _float  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat(reverse: true);
    _bar    = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _bar.forward();
    _playStartupSound();
    _navigate();
  }

  Future<void> _playStartupSound() async {
    // Chrome bloque l'autoplay sans geste utilisateur — son uniquement sur mobile
    if (kIsWeb) return;
    try {
      await _player.play(
        AssetSource('sounds/startup.wav'),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('Splash audio error: $e');
    }
  }

  @override
  void dispose() {
    _ring1.dispose(); _ring2.dispose(); _ring3.dispose();
    _pulse.dispose(); _orbit.dispose(); _float.dispose();
    _bar.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    final ok = await ref.read(authProvider.notifier).checkAuth();
    if (!mounted) return;
    context.go(ok ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1 — Fond radial
            _Background(pulse: _pulse),
            // 2 — Grille perspective
            const CustomPaint(painter: _GridPainter()),
            // 3 — Halo central
            Center(child: _Halo(pulse: _pulse)),
            // 4 — Particules orbitales 3D
            Center(child: _OrbitalParticles(orbit: _orbit)),
            // 5 — Gyroscope 3 anneaux
            Center(child: _Gyroscope(r1: _ring1, r2: _ring2, r3: _ring3)),
            // 6 — Logo flottant
            Center(child: _FloatingLogo(pulse: _pulse, float: _float)),
            // 7 — Textes
            _Labels(),
            // 8 — Barre de chargement
            _LoadingBar(bar: _bar),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOND RADIAL
// ─────────────────────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  final AnimationController pulse;
  const _Background({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = pulse.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.4,
              colors: [
                _kBlue.withValues(alpha: 0.10 + t * 0.06),
                _kViolet.withValues(alpha: 0.05 + t * 0.03),
                _kBg,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRILLE PERSPECTIVE
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kBlue.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;

    final vp = Offset(size.width / 2, size.height * 0.62);

    // Lignes horizontales (perspective quadratique)
    for (int i = 1; i <= 12; i++) {
      final ratio = i / 12;
      final y = vp.dy + (size.height - vp.dy) * (ratio * ratio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Lignes radiales convergeant vers le point de fuite
    const cols = 14;
    for (int i = 0; i <= cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, size.height), vp, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// HALO CENTRAL
// ─────────────────────────────────────────────────────────────────────────────

class _Halo extends StatelessWidget {
  final AnimationController pulse;
  const _Halo({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = pulse.value;
        return Container(
          width: 340,
          height: 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _kBlue.withValues(alpha: 0.14 + t * 0.10),
                _kViolet.withValues(alpha: 0.07 + t * 0.06),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICULES ORBITALES 3D
// ─────────────────────────────────────────────────────────────────────────────

class _OrbitalParticles extends StatelessWidget {
  final AnimationController orbit;
  const _OrbitalParticles({required this.orbit});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbit,
      builder: (_, __) => CustomPaint(
        size: const Size(440, 440),
        painter: _ParticlePainter(progress: orbit.value),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  const _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const fov = 500.0;

    // 3 orbites avec inclinaisons différentes
    final orbits = [
      (radius: 160.0, tilt: pi / 6,      speed: 1.0,  color: _kBlue,   count: 4, dotSize: 2.5),
      (radius: 120.0, tilt: pi / 2.2,    speed: -1.4, color: _kViolet, count: 3, dotSize: 2.0),
      (radius: 90.0,  tilt: pi * 0.72,   speed: 1.8,  color: _kCyan,   count: 5, dotSize: 1.5),
    ];

    for (final orb in orbits) {
      for (int i = 0; i < orb.count; i++) {
        final phase = i * 2 * pi / orb.count;
        final angle = phase + progress * 2 * pi * orb.speed;

        // Position 3D sur un cercle incliné autour de l'axe X
        final x3 = cos(angle) * orb.radius;
        final y3 = sin(angle) * orb.radius * cos(orb.tilt);
        final z3 = sin(angle) * orb.radius * sin(orb.tilt);

        // Projection perspective
        final p = fov / (fov + z3);
        final sx = center.dx + x3 * p;
        final sy = center.dy + y3 * p;

        // Plus grand et plus opaque quand proche (z petit)
        final depth = (z3 + orb.radius) / (2 * orb.radius); // 0..1
        final particleR = orb.dotSize * (0.5 + depth * 1.0) * p;
        final alpha = 0.25 + depth * 0.70;

        // Point principal
        canvas.drawCircle(
          Offset(sx, sy),
          particleR,
          Paint()..color = orb.color.withValues(alpha: alpha.clamp(0, 1)),
        );

        // Halo autour du point
        if (depth > 0.6) {
          canvas.drawCircle(
            Offset(sx, sy),
            particleR * 2.5,
            Paint()
              ..color = orb.color.withValues(alpha: (alpha * 0.3).clamp(0, 1))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// GYROSCOPE — 3 ANNEAUX 3D
// ─────────────────────────────────────────────────────────────────────────────

class _Gyroscope extends StatelessWidget {
  final AnimationController r1, r2, r3;
  const _Gyroscope({required this.r1, required this.r2, required this.r3});

  static Matrix4 _perspective(double rotY, {double preX = 0, double preZ = 0}) =>
      (Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(preX)
        ..rotateZ(preZ)
        ..rotateY(rotY * 2 * pi));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau 1 — bleu vif, horizontal
          AnimatedBuilder(
            animation: r1,
            builder: (_, __) => Transform(
              transform: _perspective(r1.value, preX: 0.2),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(210, 210),
                painter: _RingPainter(
                  color: _kBlue, strokeWidth: 1.8, alpha: 0.75, dashed: true,
                ),
              ),
            ),
          ),
          // Anneau 2 — violet, incliné 60°
          AnimatedBuilder(
            animation: r2,
            builder: (_, __) => Transform(
              transform: _perspective(r2.value, preX: 0.6, preZ: pi / 4),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _RingPainter(
                  color: _kViolet, strokeWidth: 1.6, alpha: 0.70, dashed: false,
                ),
              ),
            ),
          ),
          // Anneau 3 — cyan, presque vertical
          AnimatedBuilder(
            animation: r3,
            builder: (_, __) => Transform(
              transform: _perspective(r3.value, preX: 1.1, preZ: -pi / 6),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(110, 110),
                painter: _RingPainter(
                  color: _kCyan, strokeWidth: 1.2, alpha: 0.85, dashed: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double alpha;
  final bool dashed;
  const _RingPainter({
    required this.color, required this.strokeWidth,
    required this.alpha, required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - strokeWidth;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawCircle(c, r, paint);
      // Satellite marker (point lumineux sur l'anneau)
      canvas.drawCircle(
        Offset(c.dx + r, c.dy),
        strokeWidth * 2.2,
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset(c.dx + r, c.dy),
        strokeWidth * 4,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    } else {
      // Cercle en tirets
      final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      const dashLen = 10.0;
      const gapLen  = 5.0;
      for (final m in path.computeMetrics()) {
        double dist = 0;
        bool draw = true;
        while (dist < m.length) {
          final seg = draw ? dashLen : gapLen;
          if (draw) canvas.drawPath(m.extractPath(dist, dist + seg), paint);
          dist += seg;
          draw = !draw;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGO FLOTTANT
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingLogo extends StatelessWidget {
  final AnimationController pulse, float;
  const _FloatingLogo({required this.pulse, required this.float});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, float]),
      builder: (_, child) {
        final t  = pulse.value;
        final ft = (float.value - 0.5);
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(ft * 0.18)
            ..rotateY(ft * 0.24),
          alignment: Alignment.center,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBlue, _kViolet],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withValues(alpha: 0.35 + t * 0.30),
                  blurRadius: 28 + t * 18,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _kViolet.withValues(alpha: 0.20 + t * 0.18),
                  blurRadius: 50,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 800.ms)
    .scale(begin: const Offset(0.4, 0.4), curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LABELS
// ─────────────────────────────────────────────────────────────────────────────

class _Labels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Text(
            'ARCANA TECH',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _kWhite,
              letterSpacing: 5,
            ),
          )
          .animate()
          .fadeIn(delay: 350.ms, duration: 700.ms)
          .slideY(begin: 0.4, curve: Curves.easeOutCubic),

          const SizedBox(height: 10),

          // Sous-titre gradient
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [_kCyan, _kViolet],
            ).createShader(b),
            child: Text(
              'Espace Étudiant',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 550.ms, duration: 600.ms)
          .slideY(begin: 0.3, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRE DE CHARGEMENT
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  final AnimationController bar;
  const _LoadingBar({required this.bar});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 44,
      left: 48,
      right: 48,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: bar,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Track
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: _kWhite.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Fill
                  FractionallySizedBox(
                    widthFactor: bar.value,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [_kBlue, _kCyan, _kViolet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kCyan.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .animate()
          .fadeIn(delay: 600.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
