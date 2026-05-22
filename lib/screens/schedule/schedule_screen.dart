import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/timetable_entry.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../shell/app_shell.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _blue      = Color(0xFF2563EB);
const _blueDark  = Color(0xFF1D4ED8);
const _blueLight = Color(0xFF3B82F6);
const _green     = Color(0xFF10B981);
const _purple    = Color(0xFF8B5CF6);
const _orange    = Color(0xFFF59E0B);

// ── Constants ─────────────────────────────────────────────────────────────────
const _dayNames = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const _dayShort = ['', 'L', 'M', 'M', 'J', 'V', 'S'];
const _months   = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

// ─── Écran Emploi du temps ────────────────────────────────────────────────────

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with TickerProviderStateMixin {
  late int _selectedDay;
  bool _slideLeft = true;

  late AnimationController _nowCtl; // pulsation point "EN COURS"
  Timer? _clockTimer;               // auto-refresh + animation tick

  @override
  void initState() {
    super.initState();
    // Démarre sur le jour actuel (1=Lun … 6=Sam), sinon Lundi
    final wd = DateTime.now().weekday;
    _selectedDay = (wd >= 1 && wd <= 6) ? wd : 1;

    _nowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    Future.microtask(
      () => ref.read(scheduleProvider.notifier).loadSchedule(),
    );

    // Rafraîchissement auto toutes les 30 s + tick pour l'animation horaire
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.read(scheduleProvider.notifier).loadSchedule();
      setState(() {}); // redessine les horaires animés
    });
  }

  @override
  void dispose() {
    _nowCtl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──
  void _goDay(int delta) {
    final next = (_selectedDay + delta).clamp(1, 6);
    if (next == _selectedDay) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slideLeft = delta > 0;
      _selectedDay = next;
    });
  }

  DateTime _dateForDay(int weekday) {
    final now = DateTime.now();
    return now.add(Duration(days: weekday - now.weekday));
  }

  bool _isCourseNow(TimetableEntry c) {
    final now = DateTime.now();
    if (now.weekday != _selectedDay) return false;
    final start = _parseTime(c.startTime, now);
    final end   = _parseTime(c.endTime, now);
    return now.isAfter(start) && now.isBefore(end);
  }

  bool _isCourseInPast(TimetableEntry c) {
    final now = DateTime.now();
    if (now.weekday > _selectedDay) return true;
    if (now.weekday < _selectedDay) return false;
    final end = _parseTime(c.endTime, now);
    return now.isAfter(end);
  }

  DateTime _parseTime(String time, DateTime base) {
    final parts = time.split(':');
    if (parts.length < 2) return base;
    return DateTime(base.year, base.month, base.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  String _sessionType(TimetableEntry c) {
    if (_isCourseNow(c)) return 'EN COURS';
    final n = c.courseName.toUpperCase();
    if (n.startsWith('TP ') || n.contains(' TP ') || n.endsWith(' TP')) return 'TP';
    if (n.startsWith('TD ') || n.contains(' TD ') || n.endsWith(' TD')) return 'TD';
    return 'COURS';
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'EN COURS': return _green;
      case 'TP':       return _orange;
      case 'TD':       return _purple;
      default:         return _blue;
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(scheduleProvider);
    final date     = _dateForDay(_selectedDay);
    final isToday  = DateTime.now().weekday == _selectedDay;
    final courses  = state.forDay(_selectedDay);
    final dayLabel = '${_dayNames[_selectedDay]}  ${date.day} ${_months[date.month]}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emploi du temps',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isToday)
                        Text(
                          'Aujourd\'hui',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _blueLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms),

            const SizedBox(height: 18),

            // ── Day pills ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final d    = i + 1;
                  final sel  = d == _selectedDay;
                  final date = _dateForDay(d);
                  return GestureDetector(
                    onTap: () {
                      if (d == _selectedDay) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        _slideLeft = d > _selectedDay;
                        _selectedDay = d;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: 44, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: sel
                            ? const LinearGradient(
                                colors: [_blue, _blueDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: sel ? null : Colors.white.withValues(alpha: 0.85),
                        border: Border.all(
                          color: sel
                              ? Colors.transparent
                              : Colors.black.withValues(alpha: 0.07),
                        ),
                        boxShadow: sel
                            ? [BoxShadow(
                                color: _blue.withValues(alpha: 0.30),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              )]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayShort[d],
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : AppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: sel
                                  ? Colors.white
                                  : (DateTime.now().weekday == d
                                      ? _blueLight
                                      : AppTheme.textSecondary),
                            ),
                          ),
                          // Dot si cours ce jour
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : (ref.watch(scheduleProvider)
                                          .forDay(d)
                                          .isNotEmpty
                                      ? _blueLight.withValues(alpha: 0.5)
                                      : Colors.transparent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.04),

            const SizedBox(height: 20),

            // ── Day heading row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  // Left arrow
                  GestureDetector(
                    onTap: () => _goDay(-1),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedDay > 1
                            ? _blue.withValues(alpha: 0.10)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: _selectedDay > 1
                            ? _blue
                            : AppTheme.textTertiary.withValues(alpha: 0.25),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Day label (animated)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(_slideLeft ? 0.15 : -0.15, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      ),
                      child: Text(
                        dayLabel,
                        key: ValueKey(_selectedDay),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isToday ? _blue : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Right arrow
                  GestureDetector(
                    onTap: () => _goDay(1),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedDay < 6
                            ? _blue.withValues(alpha: 0.10)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _selectedDay < 6
                            ? _blue
                            : AppTheme.textTertiary.withValues(alpha: 0.25),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Course list ──────────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(child: LoadingIndicator())
                  : state.error != null && state.entries.isEmpty
                      ? _ErrorState(message: state.error!)
                      : courses.isEmpty
                      ? const _EmptyDay()
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                          child: ListView.builder(
                            key: ValueKey(_selectedDay),
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 22, right: 22,
                            ).copyWith(bottom: kBottomNavClearance),
                            itemCount: courses.length,
                            itemBuilder: (ctx, i) {
                              final c      = courses[i];
                              final type   = _sessionType(c);
                              final color  = _badgeColor(type);
                              final isNow  = type == 'EN COURS';
                              final isPast = _isCourseInPast(c);

                              return _CourseCard(
                                course:     c,
                                type:       type,
                                badgeColor: color,
                                isNow:      isNow,
                                isPast:     isPast,
                                isLast:     i == courses.length - 1,
                                nowAnim:    _nowCtl,
                              )
                                  .animate()
                                  .fadeIn(
                                    duration: 320.ms,
                                    delay: Duration(milliseconds: i * 55),
                                  )
                                  .slideX(begin: 0.06);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte de cours ───────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final TimetableEntry     course;
  final String             type;
  final Color              badgeColor;
  final bool               isNow;
  final bool               isPast;
  final bool               isLast;
  final Animation<double>  nowAnim;

  const _CourseCard({
    required this.course,
    required this.type,
    required this.badgeColor,
    required this.isNow,
    required this.isPast,
    required this.isLast,
    required this.nowAnim,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isPast
        ? AppTheme.textTertiary.withValues(alpha: 0.3)
        : badgeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Colonne heure (gauche) ───────────────────────────────────────
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: isNow
                    ? _AnimatedTimeColumn(
                        startTime: course.startTime,
                        endTime:   course.endTime,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            course.startTime,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isPast
                                  ? AppTheme.textTertiary
                                  : _blue,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            course.endTime,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textTertiary.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(width: 10),

            // ── Connecteur (point + ligne) ───────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 6),
                // Point pulsant si EN COURS
                AnimatedBuilder(
                  animation: nowAnim,
                  builder: (_, __) => Container(
                    width:  isNow ? 12 : 10,
                    height: isNow ? 12 : 10,
                    decoration: BoxDecoration(
                      shape:  BoxShape.circle,
                      color:  dotColor,
                      boxShadow: isNow
                          ? [
                              BoxShadow(
                                color: badgeColor.withValues(
                                  alpha: 0.35 + nowAnim.value * 0.25,
                                ),
                                blurRadius: 8 + nowAnim.value * 5,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                // Ligne vers prochain cours
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: dotColor.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Card ─────────────────────────────────────────────────────────
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: isPast ? 0.50 : 1.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isNow
                        ? _green.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.90),
                    border: Border.all(
                      width: isNow ? 1.5 : 1,
                      color: isNow
                          ? _green.withValues(alpha: 0.30)
                          : Colors.black.withValues(alpha: 0.07),
                    ),
                    boxShadow: isNow
                        ? [
                            BoxShadow(
                              color: _green.withValues(alpha: 0.07),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Nom + badge ──────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.courseName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isPast
                                    ? AppTheme.textTertiary
                                    : AppTheme.textPrimary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeBadge(label: type, color: badgeColor),
                        ],
                      ),

                      // ── Salle ────────────────────────────────────────────
                      if (course.roomName != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 13,
                              color: AppTheme.textTertiary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                course.roomName!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── Enseignant ───────────────────────────────────────
                      if (course.teacherName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _blue.withValues(alpha: 0.10),
                                border: Border.all(
                                  color: _blue.withValues(alpha: 0.20),
                                ),
                              ),
                              child: const Icon(
                                Iconsax.user,
                                size: 12,
                                color: _blue,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                course.teacherName!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── Code du cours ────────────────────────────────────
                      if (course.courseCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          course.courseCode!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: _blue.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Colonne horaire animée (EN COURS) ───────────────────────────────────────
/// Affiche l'heure de début, l'heure actuelle animée (descend chaque minute)
/// et l'heure de fin pour les cours en cours.

class _AnimatedTimeColumn extends StatefulWidget {
  final String startTime;
  final String endTime;
  const _AnimatedTimeColumn({required this.startTime, required this.endTime});

  @override
  State<_AnimatedTimeColumn> createState() => _AnimatedTimeColumnState();
}

class _AnimatedTimeColumnState extends State<_AnimatedTimeColumn> {
  late Timer _minuteTimer;
  late String _nowStr;

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _nowStr = _fmt(DateTime.now());
    // Recalcule à chaque minute juste
    final secsUntilNextMinute = 60 - DateTime.now().second;
    Future.delayed(Duration(seconds: secsUntilNextMinute), () {
      if (!mounted) return;
      setState(() => _nowStr = _fmt(DateTime.now()));
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _nowStr = _fmt(DateTime.now()));
      });
    });
    // Timer provisoire pour le premier délai (remplacé ci-dessus)
    _minuteTimer = Timer(Duration.zero, () {});
  }

  @override
  void dispose() {
    _minuteTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Heure de début (fixe)
        Text(
          widget.startTime,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textTertiary.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 4),

        // Heure actuelle animée — descend comme une pendule
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve:  Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin:  const Offset(0, -0.8),
                end:    Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              _nowStr,
              key: ValueKey(_nowStr),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),
        // Heure de fin (fixe)
        Text(
          widget.endTime,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textTertiary.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ─── Badge de type ────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color:  color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── État erreur ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.danger.withValues(alpha: 0.07),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.14)),
              ),
              child: Icon(Iconsax.wifi_square, size: 32, color: AppTheme.danger),
            ),
            const SizedBox(height: 18),
            Text(
              'Emploi du temps indisponible',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.92, 0.92));
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withValues(alpha: 0.07),
              border: Border.all(color: _blue.withValues(alpha: 0.14)),
            ),
            child: const Icon(Iconsax.calendar_remove, size: 32, color: _blue),
          ),
          const SizedBox(height: 18),
          Text(
            'Aucun cours',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pas de séance programmée ce jour',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.92, 0.92));
  }
}
