import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/timetable_entry.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../shell/app_shell.dart';

// ─── Palette locale ──────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF2563EB);
const _kIndigo = Color(0xFF4F46E5);
const _kViolet = Color(0xFF7C3AED);
const _kCoral  = Color(0xFFF97316);
const _kGreen  = Color(0xFF10B981);
const _kAmber  = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// ─── HomeScreenState ──────────────────────────────────────────────────────────

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtl;
  late AnimationController _orbCtl;
  Timer? _timer;
  Duration _countdown = Duration.zero;
  TimetableEntry? _nextCourse;

  /// Icône + label selon l'heure locale (remplace la météo fictive)
  Map<String, String> get _timeContext {
    final h = DateTime.now().hour;
    if (h < 6)  return {'icon': '🌙', 'temp': 'Nuit calme'};
    if (h < 12) return {'icon': '🌅', 'temp': 'Matin frais'};
    if (h < 18) return {'icon': '☀️', 'temp': 'Journée active'};
    return {'icon': '🌆', 'temp': 'Soirée'};
  }

  @override
  void initState() {
    super.initState();
    _pulseCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _orbCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
    Future.microtask(() {
      ref.read(studentProvider.notifier).loadStats();
      ref.read(scheduleProvider.notifier).loadSchedule();
    });
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    _orbCtl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _initCountdown(List<TimetableEntry> courses) {
    final next = _findNext(courses);
    if (next == null || next.id == _nextCourse?.id) return;
    _nextCourse = next;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown = _calcCountdown(_nextCourse!));
    });
    setState(() => _countdown = _calcCountdown(next));
  }

  TimetableEntry? _findNext(List<TimetableEntry> courses) {
    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;
    TimetableEntry? best;
    int minDiff = 9999;
    for (final c in courses) {
      final parts = c.startTime.split(':');
      if (parts.length < 2) continue;
      final cMins = (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
      if (cMins > nowMins) {
        final diff = cMins - nowMins;
        if (diff < minDiff) {
          minDiff = diff;
          best = c;
        }
      }
    }
    return best;
  }

  Duration _calcCountdown(TimetableEntry c) {
    final now = DateTime.now();
    final parts = c.startTime.split(':');
    if (parts.length < 2) return Duration.zero;
    final target = DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    final diff = target.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatCountdown(Duration d) {
    if (d.inSeconds <= 0) return 'EN COURS';
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅';
    if (h < 18) return '☀️';
    return '🌙';
  }

  String _formattedDate() {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  bool get _isMorning => DateTime.now().hour < 12;

  void _showQROverlay(BuildContext ctx, User user) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierLabel: 'Fermer',
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (c, a1, a2) => _QRCardOverlay(user: user),
      transitionBuilder: (c, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, -1.2), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState    = ref.watch(authProvider);
    final studentState = ref.watch(studentProvider);
    final scheduleState = ref.watch(scheduleProvider);
    final user = authState.user;

    final today = DateTime.now().weekday;
    final todayCourses = scheduleState.forDay(today);

    if (!scheduleState.isLoading && todayCourses.isNotEmpty) {
      _initCountdown(todayCourses);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        body: Stack(
          children: [
            // ── Ambient orbs ────────────────────────────────
            AnimatedBuilder(
              animation: _orbCtl,
              builder: (_, __) {
                final a = _orbCtl.value * 2 * math.pi;
                return Stack(children: [
                  Positioned(
                    top: 200 + math.sin(a) * 30,
                    right: -60 + math.cos(a) * 20,
                    child: _GlowOrb(color: _kIndigo, size: 280, opacity: 0.07),
                  ),
                  Positioned(
                    top: 400 + math.cos(a) * 20,
                    left: -80,
                    child: _GlowOrb(color: _kCoral, size: 240, opacity: 0.05),
                  ),
                ]);
              },
            ),

            // ── Main scroll ─────────────────────────────────
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [

                // ════════════════════════════════════════════
                // HEADER GRADIENT (safe area + greeting + hero)
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _GradientHeader(
                    user: user,
                    greeting: _greeting(),
                    greetingEmoji: _greetingEmoji(),
                    date: _formattedDate(),
                    weather: _timeContext,
                    nextCourse: scheduleState.isLoading ? null : _nextCourse,
                    countdown: _countdown,
                    pulseAnim: _pulseCtl,
                    onFormatCountdown: _formatCountdown,
                    isMorning: _isMorning,
                    isLoading: scheduleState.isLoading,
                    onAvatarTap: user != null
                        ? () => _showQROverlay(context, user)
                        : null,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ════════════════════════════════════════════
                // STATS
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Mes statistiques', onSeeAll: null),
                      const SizedBox(height: 10),
                      if (studentState.isLoading)
                        // ── Skeleton loading ──
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: List.generate(4, (_) =>
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Container(
                                  width: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                    )],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (studentState.error != null && studentState.stats == null)
                        // ── Erreur ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _kRed.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _kRed.withValues(alpha: 0.15)),
                            ),
                            child: Row(children: [
                              Icon(Iconsax.warning_2, color: _kRed, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(studentState.error!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, color: _kRed,
                                  )),
                              ),
                            ]),
                          ),
                        )
                      else if (studentState.stats != null)
                        // ── Données ──
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              _StatCard(
                                label: 'Présences',
                                value: '${studentState.stats!.totalSessions - studentState.stats!.lateCount - studentState.stats!.absentCount}',
                                icon: Iconsax.tick_circle,
                                color: _kGreen,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'Retards',
                                value: '${studentState.stats!.lateCount}',
                                icon: Iconsax.clock,
                                color: _kAmber,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'Absences',
                                value: '${studentState.stats!.absentCount}',
                                icon: Iconsax.close_circle,
                                color: _kRed,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'Taux',
                                value: '${studentState.stats!.presenceRate.toStringAsFixed(0)}%',
                                icon: Iconsax.chart_2,
                                color: _kBlue,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ════════════════════════════════════════════
                // ACTIONS RAPIDES
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Actions rapides', onSeeAll: null),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Iconsax.wifi,
                                label: 'Scanner RFID',
                                sub: 'Valider ma présence',
                                gradient: const LinearGradient(
                                  colors: [_kBlue, _kIndigo],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  context.push('/scanner');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Iconsax.medal_star,
                                label: 'Mes Notes',
                                sub: 'Hub & résultats',
                                gradient: const LinearGradient(
                                  colors: [_kViolet, _kCoral],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  context.push('/grades');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Iconsax.document_upload,
                                label: 'Justifier',
                                sub: 'Absence · Retard',
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  context.push('/justification');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: Iconsax.notification,
                                label: 'Alertes',
                                sub: 'Mes notifications',
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  context.push('/notifications');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ════════════════════════════════════════════
                // COURS DU JOUR
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: "Aujourd'hui",
                    onSeeAll: () => context.go('/schedule'),
                  ).animate().fadeIn(delay: 280.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                if (scheduleState.isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: LoadingIndicator(),
                      ),
                    ),
                  )
                else if (todayCourses.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Iconsax.calendar_remove,
                      message: "Aucun cours aujourd'hui 🎉",
                    ).animate().fadeIn(delay: 300.ms),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _CourseTile(
                          course: todayCourses[i],
                          index: i,
                          isNext: todayCourses[i].id == _nextCourse?.id,
                        ),
                      ),
                      childCount: todayCourses.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ════════════════════════════════════════════
                // PRÉSENCES RÉCENTES
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'Présences récentes',
                    onSeeAll: () => context.push('/attendance'),
                  ).animate().fadeIn(delay: 340.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                if (studentState.stats?.recentAttendances.isNotEmpty == true)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final a = studentState.stats!.recentAttendances[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: _AttendanceRow(
                            courseName: a.courseName ?? 'Cours',
                            date: a.date,
                            status: a.status,
                          ),
                        );
                      },
                      childCount: studentState.stats!.recentAttendances.length
                          .clamp(0, 3),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Iconsax.document_text,
                      message: 'Aucune présence récente',
                    ),
                  ),

                SliverToBoxAdapter(
                    child: SizedBox(height: kBottomNavClearance)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GRADIENT HEADER
// ═════════════════════════════════════════════════════════════════════════════

class _GradientHeader extends StatelessWidget {
  final User? user;
  final String greeting;
  final String greetingEmoji;
  final String date;
  final Map<String, String> weather;
  final TimetableEntry? nextCourse;
  final Duration countdown;
  final Animation<double> pulseAnim;
  final String Function(Duration) onFormatCountdown;
  final bool isMorning;
  final bool isLoading;
  final VoidCallback? onAvatarTap;

  const _GradientHeader({
    required this.user,
    required this.greeting,
    required this.greetingEmoji,
    required this.date,
    required this.weather,
    required this.nextCourse,
    required this.countdown,
    required this.pulseAnim,
    required this.onFormatCountdown,
    required this.isMorning,
    required this.isLoading,
    required this.onAvatarTap,
  });

  bool get _urgent => countdown.inMinutes < 15 && countdown.inSeconds > 0;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // bleu-900
            Color(0xFF2563EB), // bleu-600
            Color(0xFF4F46E5), // indigo-600
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Orbes décoratifs dans le header
          Positioned(
            top: topPad + 8,
            right: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -40,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Top bar : date + avatar ──
                Row(
                  children: [
                    // Date pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.calendar_1,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(date,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Météo
                    if (isMorning)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          children: [
                            Text(weather['icon']!,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(weather['temp']!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Avatar
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: AnimatedBuilder(
                        animation: pulseAnim,
                        builder: (_, __) => Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.20),
                            border: Border.all(
                              color: Colors.white.withValues(
                                  alpha: 0.4 + pulseAnim.value * 0.2),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              user?.firstName.isNotEmpty == true
                                  ? user!.firstName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 20),

                // ── Greeting ──
                Text(
                  '$greetingEmoji  $greeting,',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 60.ms, duration: 400.ms),
                const SizedBox(height: 2),
                Text(
                  user?.firstName ?? 'Étudiant',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 22),

                // ── Carte prochain cours ──
                if (isLoading)
                  _HeroSkeletonLight()
                else if (nextCourse != null)
                  _NextClassCard(
                    course: nextCourse!,
                    countdown: countdown,
                    pulseAnim: pulseAnim,
                    onFormatCountdown: onFormatCountdown,
                    urgent: _urgent,
                  ).animate().fadeIn(delay: 120.ms, duration: 500.ms)
                else
                  _NoCourseCard(isMorning: isMorning)
                    .animate().fadeIn(delay: 120.ms, duration: 400.ms),

                // ── QR hint ──
                const SizedBox(height: 14),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.scan, size: 11,
                          color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 5),
                      Text('Appuyer sur votre avatar pour la carte étudiante',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          )),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte prochain cours (dans le header) ───────────────────────────────────

class _NextClassCard extends StatelessWidget {
  final TimetableEntry course;
  final Duration countdown;
  final Animation<double> pulseAnim;
  final String Function(Duration) onFormatCountdown;
  final bool urgent;

  const _NextClassCard({
    required this.course,
    required this.countdown,
    required this.pulseAnim,
    required this.onFormatCountdown,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(
          color: urgent
              ? const Color(0xFFF97316).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Left info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: urgent
                        ? const Color(0xFFF97316).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    urgent ? '⚠️  BIENTÔT' : 'PROCHAIN COURS',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  course.courseName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Iconsax.location, size: 12,
                      color: Colors.white.withValues(alpha: 0.65)),
                  const SizedBox(width: 4),
                  Text(course.roomName ?? '—',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                      )),
                  if (course.teacherName != null) ...[
                    const SizedBox(width: 10),
                    Icon(Iconsax.user, size: 12,
                        color: Colors.white.withValues(alpha: 0.65)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(course.teacherName!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Countdown circle
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              width: 74, height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13 + pulseAnim.value * 0.05),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    onFormatCountdown(countdown),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: countdown.inHours >= 1 ? 12 : 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('DANS',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.8,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aucun cours (dans le header) ───────────────────────────────────────────

class _NoCourseCard extends StatelessWidget {
  final bool isMorning;
  const _NoCourseCard({required this.isMorning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMorning ? 'Aucun cours ce matin' : 'Cours terminés !',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isMorning
                      ? 'Profitez-en pour réviser'
                      : 'Belle fin de journée 🌙',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton (dans le header) ───────────────────────────────────────────────

class _HeroSkeletonLight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Center(
        child: LoadingIndicator(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION TITLE
// ═════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionTitle({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _kBlue.withValues(alpha: 0.08),
                ),
                child: Text('Voir tout',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kBlue,
                    )),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  )),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9CA3AF),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sub;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: widget.gradient,
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 14),
              Text(widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              const SizedBox(height: 2),
              Text(widget.sub,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.70),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COURSE TILE
// ═════════════════════════════════════════════════════════════════════════════

class _CourseTile extends StatelessWidget {
  final TimetableEntry course;
  final int index;
  final bool isNext;

  const _CourseTile({
    required this.course,
    required this.index,
    this.isNext = false,
  });

  static const _palette = [_kBlue, _kViolet, _kGreen, _kCoral, _kAmber];

  Color get _accentColor => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(
          color: isNext
              ? _accentColor.withValues(alpha: 0.35)
              : const Color(0x10000000),
          width: isNext ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: isNext ? 0.10 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                course.startTime,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
              Container(
                width: 1.5, height: 14,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: _accentColor.withValues(alpha: 0.25),
              ),
              Text(
                course.endTime,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Color bar
          Container(
            width: 3, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_accentColor, _accentColor.withValues(alpha: 0.15)],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Course info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.courseName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  if (course.roomName != null) ...[
                    Icon(Iconsax.building, size: 11,
                        color: const Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(course.roomName!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        )),
                    const SizedBox(width: 8),
                  ],
                  if (course.teacherName != null) ...[
                    Icon(Iconsax.user, size: 11,
                        color: const Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(course.teacherName!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),

          if (isNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _accentColor,
              ),
              child: Text('NEXT',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  )),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ATTENDANCE ROW
// ═════════════════════════════════════════════════════════════════════════════

class _AttendanceRow extends StatelessWidget {
  final String courseName;
  final String date;
  final String status;

  const _AttendanceRow({
    required this.courseName,
    required this.date,
    required this.status,
  });

  Color get _color {
    switch (status) {
      case 'present': return _kGreen;
      case 'late':    return _kAmber;
      default:        return _kRed;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'present': return Iconsax.tick_circle;
      case 'late':    return Iconsax.clock;
      default:        return Iconsax.close_circle;
    }
  }

  String get _label {
    switch (status) {
      case 'present': return 'Présent';
      case 'late':    return 'Retard';
      default:        return 'Absent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _color.withValues(alpha: 0.10),
            ),
            child: Icon(_icon, size: 20, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(date,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _color.withValues(alpha: 0.10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _color,
                ),
              ),
              const SizedBox(width: 5),
              Text(_label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: const Color(0x0A000000)),
        ),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF3F4F6),
            ),
            child: Icon(icon, size: 26, color: const Color(0xFFD1D5DB)),
          ),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              )),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GLOW ORB
// ═════════════════════════════════════════════════════════════════════════════

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QR CARD OVERLAY
// ═════════════════════════════════════════════════════════════════════════════

class _QRCardOverlay extends StatelessWidget {
  final User user;
  const _QRCardOverlay({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white,
                  border: Border.all(
                    color: _kBlue.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.15),
                      blurRadius: 48,
                      spreadRadius: 4,
                    ),
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_kBlue, _kIndigo],
                          ),
                        ),
                        child: const Center(
                          child: Text('🎓', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.university?.name ?? 'Les Cours Sonou',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('CARTE ÉTUDIANT NUMÉRIQUE',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: const Color(0xFF9CA3AF),
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _kGreen.withValues(alpha: 0.10),
                          border: Border.all(
                              color: _kGreen.withValues(alpha: 0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 5, height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('VALIDE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _kGreen,
                                letterSpacing: 0.5,
                              )),
                        ]),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    Divider(color: const Color(0xFF000000).withValues(alpha: 0.06)),
                    const SizedBox(height: 14),

                    // Infos étudiant
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [_kBlue, _kViolet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              user.firstName.isNotEmpty
                                  ? user.firstName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF111827),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.filiere ?? 'Filière non définie',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _kBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, children: [
                                _InfoChip(label: user.registrationNumber ?? '—'),
                                _InfoChip(label: user.level ?? '—'),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(
                            color: const Color(0xFF000000).withValues(alpha: 0.06)),
                      ),
                      child: CustomPaint(
                        size: const Size(130, 130),
                        painter: _QRCodePainter(
                          color: _kBlue,
                          data: user.registrationNumber ?? '0000',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text('Appuyez en dehors pour fermer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0x10000000)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

// ─── QR Code Painter ─────────────────────────────────────────────────────────

class _QRCodePainter extends CustomPainter {
  final Color color;
  final String data;
  const _QRCodePainter({required this.color, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const modules = 21;
    final ms = size.width / modules;
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (_draw(r, c)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * ms + 0.5, r * ms + 0.5, ms - 1, ms - 1),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  bool _draw(int r, int c) {
    if (r < 8 && c < 8) return _fp(r, c);
    if (r < 8 && c >= 13) return _fp(r, c - 13);
    if (r >= 13 && c < 8) return _fp(r - 13, c);
    if (r == 7 || r == 13 || c == 7 || c == 13) return false;
    return ((r * 31 + c * 17 + data.hashCode) % 5) < 2;
  }

  bool _fp(int r, int c) {
    if (r == 0 || r == 6 || c == 0 || c == 6) return true;
    if (r >= 2 && r <= 4 && c >= 2 && c <= 4) return true;
    return false;
  }

  @override
  bool shouldRepaint(_QRCodePainter old) =>
      old.data != data || old.color != color;
}

