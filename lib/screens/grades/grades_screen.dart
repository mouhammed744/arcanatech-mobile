import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/grade.dart';
import '../../providers/grades_provider.dart';
import '../../widgets/loading_indicator.dart';

// ─── Hub Gamifié des Notes ────────────────────────────────────────────────────

class GradesScreen extends ConsumerStatefulWidget {
  const GradesScreen({super.key});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen>
    with TickerProviderStateMixin {
  late AnimationController _xpCtl;    // Animation de la barre XP
  late AnimationController _orbCtl;   // Orbes de fond
  late AnimationController _pulseCtl; // Pulsation du niveau
  late AnimationController _ectsCtl;  // Barre ECTS
  bool _showParticles = false;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _xpCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _orbCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _pulseCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _ectsCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    Future.microtask(() async {
      await ref.read(gradesProvider.notifier).loadGrades();
      // Lancer les animations après chargement
      if (mounted) {
        _xpCtl.forward();
        _ectsCtl.forward();
      }
    });
  }

  @override
  void dispose() {
    _xpCtl.dispose();
    _orbCtl.dispose();
    _pulseCtl.dispose();
    _ectsCtl.dispose();
    super.dispose();
  }

  void _celebrateECTS() {
    HapticFeedback.heavyImpact();
    setState(() {
      _showParticles = true;
      _particles.clear();
      final rng = math.Random();
      for (int i = 0; i < 20; i++) {
        _particles.add(_Particle(
          color: [
            AppTheme.cyan,
            AppTheme.violet,
            AppTheme.coral,
            AppTheme.success,
            AppTheme.warning,
          ][rng.nextInt(5)],
          angle: rng.nextDouble() * 2 * math.pi,
          distance: 80 + rng.nextDouble() * 120,
        ));
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showParticles = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradesState = ref.watch(gradesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // ── Orbes de fond animés ──
          AnimatedBuilder(
            animation: _orbCtl,
            builder: (_, __) {
              final a = _orbCtl.value * 2 * math.pi;
              return Stack(children: [
                Positioned(
                  top: -40 + math.sin(a) * 15,
                  right: -60,
                  child: _GlowOrb(
                      color: AppTheme.violet, size: 300, opacity: 0.07),
                ),
                Positioned(
                  top: 300 + math.cos(a) * 20,
                  left: -80,
                  child: _GlowOrb(
                      color: AppTheme.cyan, size: 260, opacity: 0.05),
                ),
                Positioned(
                  bottom: 200,
                  right: -50 + math.sin(a) * 15,
                  child: _GlowOrb(
                      color: AppTheme.coral, size: 220, opacity: 0.04),
                ),
              ]);
            },
          ),

          // ── Contenu principal ──
          SafeArea(
            bottom: false,
            child: gradesState.isLoading
                ? const Center(child: LoadingIndicator())
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── AppBar ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 16, 16, 0),
                          child: Row(
                            children: [
                              // Bouton retour
                              GestureDetector(
                                onTap: () =>
                                    Navigator.of(context).pop(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.06),
                                    border: Border.all(
                                        color: AppTheme.cardBorder),
                                  ),
                                  child: const Icon(
                                      Icons.arrow_back_ios_rounded,
                                      size: 16,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              ShaderMask(
                                shaderCallback: (b) =>
                                    AppTheme.primaryGradient
                                        .createShader(b),
                                child: Text(
                                  'Hub des Notes',
                                  style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  color: AppTheme.violet
                                      .withValues(alpha: 0.12),
                                  border: Border.all(
                                      color: AppTheme.violet
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  gradesState.semester,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.violet),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 20)),

                      // ── Carte de Niveau (XP) ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: _LevelCard(
                            state: gradesState,
                            xpAnimation: _xpCtl,
                            pulseAnimation: _pulseCtl,
                          ),
                        ).animate().fadeIn(delay: 60.ms, duration: 500.ms),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // ── Titre Compétences ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(children: [
                            Icon(Iconsax.chart_2,
                                size: 16, color: AppTheme.cyan),
                            const SizedBox(width: 8),
                            Text('Compétences par matière',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary)),
                          ]),
                        ).animate().fadeIn(delay: 140.ms),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      // ── Grille des arcs de progression ──
                      SliverPadding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _SkillArcCard(
                              grade: gradesState.grades[i],
                              index: i,
                            )
                                .animate()
                                .fadeIn(
                                    delay: Duration(
                                        milliseconds: 180 + i * 60),
                                    duration: 400.ms)
                                .scale(
                                    begin: const Offset(0.85, 0.85),
                                    curve: Curves.elasticOut),
                            childCount: gradesState.grades.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // ── Barre ECTS ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Stack(
                            children: [
                              _ECTSCard(
                                state: gradesState,
                                ectsAnimation: _ectsCtl,
                                onCelebrate: _celebrateECTS,
                              ),
                              if (_showParticles)
                                _ParticlesBurst(
                                    particles: _particles),
                            ],
                          ),
                        ).animate().fadeIn(delay: 500.ms),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 20)),

                      // ── Trophées / Achievements ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                          child: Row(children: [
                            Icon(Iconsax.medal_star,
                                size: 16, color: AppTheme.warning),
                            const SizedBox(width: 8),
                            Text('Trophées',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary)),
                          ]),
                        ).animate().fadeIn(delay: 560.ms),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            children: [
                              _TrophyCard(
                                  icon: '🎯',
                                  title: 'Régulier',
                                  sub: '15 présences',
                                  color: AppTheme.success,
                                  unlocked: true),
                              const SizedBox(width: 10),
                              _TrophyCard(
                                  icon: '🔥',
                                  title: 'En feu',
                                  sub: '5 cours d\'affilée',
                                  color: AppTheme.coral,
                                  unlocked: true),
                              const SizedBox(width: 10),
                              _TrophyCard(
                                  icon: '⚡',
                                  title: 'Éclair',
                                  sub: 'Moy. > 15',
                                  color: AppTheme.warning,
                                  unlocked: gradesState.average >= 15),
                              const SizedBox(width: 10),
                              _TrophyCard(
                                  icon: '👑',
                                  title: 'Maître',
                                  sub: 'Tous ECTS validés',
                                  color: AppTheme.violet,
                                  unlocked: gradesState.validatedECTS ==
                                      gradesState.totalECTS),
                            ],
                          ),
                        ).animate().fadeIn(delay: 620.ms),
                      ),

                      SliverToBoxAdapter(
                          child: SizedBox(
                              height: MediaQuery.of(context).padding.bottom +
                                  24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte de Niveau (XP Bar) ─────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final GradesState state;
  final Animation<double> xpAnimation;
  final Animation<double> pulseAnimation;

  const _LevelCard({
    required this.state,
    required this.xpAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final lvl = state.levelNumber;
    final levelColors = [
      AppTheme.textTertiary,   // 0: Novice
      AppTheme.success,        // 1: Confirmé
      AppTheme.cyan,           // 2: Avancé
      AppTheme.violet,         // 3: Expert
      AppTheme.warning,        // 4: Maître
    ];
    final color = levelColors[lvl.clamp(0, 4)];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                AppTheme.violet.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Badge niveau
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                            colors: [color, AppTheme.violet]),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(
                                alpha: 0.25 +
                                    pulseAnimation.value * 0.2),
                            blurRadius: 16 + pulseAnimation.value * 6,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Row(children: [
                        Text('⚡',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'NIV. $lvl',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.levelTitle.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5),
                      ),
                      Text(
                        '→ ${state.nextLevelTitle}',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${state.average.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                      Text(
                        '/ 20',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Barre XP
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      '${state.totalXP} XP',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                    const Spacer(),
                    Text(
                      '${(state.nextLevelProgress * 100).toStringAsFixed(0)}% vers ${state.nextLevelTitle}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textTertiary),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Track
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    child: AnimatedBuilder(
                      animation: xpAnimation,
                      builder: (_, __) {
                        final progress = state.nextLevelProgress *
                            Curves.easeOutCubic
                                .transform(xpAnimation.value);
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                  colors: [color, AppTheme.violet]),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Stats rapides
              Row(
                children: [
                  _MiniStat(
                      label: 'Matières',
                      value: '${state.grades.length}',
                      color: AppTheme.cyan),
                  _Divider(),
                  _MiniStat(
                      label: 'Validées',
                      value:
                          '${state.grades.where((g) => g.isValidated).length}',
                      color: AppTheme.success),
                  _Divider(),
                  _MiniStat(
                      label: 'Total XP',
                      value: '${state.totalXP}',
                      color: AppTheme.warning),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textTertiary)),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 30, color: AppTheme.cardBorder);
  }
}

// ─── Carte arc de compétence par matière ──────────────────────────────────────

class _SkillArcCard extends StatelessWidget {
  final Grade grade;
  final int index;

  const _SkillArcCard({required this.grade, required this.index});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                grade.color.withValues(alpha: 0.10),
                grade.color.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: grade.isValidated
                  ? grade.color.withValues(alpha: 0.25)
                  : AppTheme.danger.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arc de progression
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Arc CustomPaint animé
                        TweenAnimationBuilder<double>(
                          tween:
                              Tween(begin: 0.0, end: grade.percentage),
                          duration: Duration(
                              milliseconds: 800 + index * 100),
                          curve: Curves.easeOutCubic,
                          builder: (_, progress, __) => CustomPaint(
                            size: const Size(90, 90),
                            painter: _ArcRingPainter(
                              progress: progress,
                              color: grade.isValidated
                                  ? grade.color
                                  : AppTheme.danger,
                              strokeWidth: 8,
                            ),
                          ),
                        ),
                        // Note au centre
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              grade.note.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: grade.isValidated
                                    ? grade.color
                                    : AppTheme.danger,
                              ),
                            ),
                            Text(
                              '/20',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Nom du cours
              Text(
                grade.courseName,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 3),

              Row(children: [
                Text(
                  grade.shortMention,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: grade.isValidated
                        ? grade.color
                        : AppTheme.danger,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: (grade.isValidated
                            ? AppTheme.success
                            : AppTheme.danger)
                        .withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '${grade.ects} ECTS',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: grade.isValidated
                          ? AppTheme.success
                          : AppTheme.danger,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Barre ECTS ───────────────────────────────────────────────────────────────

class _ECTSCard extends StatelessWidget {
  final GradesState state;
  final Animation<double> ectsAnimation;
  final VoidCallback onCelebrate;

  const _ECTSCard({
    required this.state,
    required this.ectsAnimation,
    required this.onCelebrate,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = state.totalECTS > 0
        ? state.validatedECTS / state.totalECTS
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.violet.withValues(alpha: 0.10),
                AppTheme.cyan.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
                color: AppTheme.violet.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🎓', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Crédits ECTS',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                const Spacer(),
                // Bouton fêter
                GestureDetector(
                  onTap: onCelebrate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: Text('🎉 Fêter',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: Text(
                      '${state.validatedECTS}',
                      style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                  Text(
                    ' / ${state.totalECTS} ECTS validés',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Barre de progression ECTS
              Stack(children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                AnimatedBuilder(
                  animation: ectsAnimation,
                  builder: (_, __) {
                    final p = ratio *
                        Curves.easeOutCubic
                            .transform(ectsAnimation.value);
                    return FractionallySizedBox(
                      widthFactor: p.clamp(0.0, 1.0),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.cyan.withValues(alpha: 0.35),
                              blurRadius: 10,
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 10),

              // Matières non validées
              if (state.grades.any((g) => !g.isValidated)) ...[
                Text(
                  'À rattraper :',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: state.grades
                      .where((g) => !g.isValidated)
                      .map((g) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(8),
                              color: AppTheme.danger
                                  .withValues(alpha: 0.1),
                              border: Border.all(
                                  color: AppTheme.danger
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '${g.courseCode} · ${g.note}/20',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trophée ──────────────────────────────────────────────────────────────────

class _TrophyCard extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;
  final Color color;
  final bool unlocked;

  const _TrophyCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: unlocked
                ? color.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: unlocked
                  ? color.withValues(alpha: 0.25)
                  : AppTheme.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unlocked ? icon : '🔒',
                style: TextStyle(
                    fontSize: 22,
                    color: unlocked ? null : Colors.white24),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: unlocked
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Burst de particules ───────────────────────────────────────────────────────

class _ParticlesBurst extends StatefulWidget {
  final List<_Particle> particles;

  const _ParticlesBurst({required this.particles});

  @override
  State<_ParticlesBurst> createState() => _ParticlesBurstState();
}

class _ParticlesBurstState extends State<_ParticlesBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        return IgnorePointer(
          child: SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: widget.particles.map((p) {
                final t = Curves.easeOut.transform(_ctl.value);
                final x = math.cos(p.angle) * p.distance * t;
                final y = math.sin(p.angle) * p.distance * t;
                return Positioned(
                  left: 150 + x,
                  top: 80 + y,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.color,
                        boxShadow: [
                          BoxShadow(
                            color: p.color.withValues(alpha: 0.6),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─── Orbe décoratif ───────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent]),
      ),
    );
  }
}

// ─── Modèles internes ─────────────────────────────────────────────────────────

class _Particle {
  final Color color;
  final double angle;
  final double distance;

  const _Particle(
      {required this.color,
      required this.angle,
      required this.distance});
}

// ─── Arc CustomPainter ────────────────────────────────────────────────────────

class _ArcRingPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;
  final double strokeWidth;

  const _ArcRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track de fond
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Arc de progression
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.progress != progress || old.color != color;
}
