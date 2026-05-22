import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/attendance_tile.dart';
import '../../widgets/loading_indicator.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(attendanceProvider.notifier).loadAttendances());
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final all = attendanceState.records;
    final filtered = _filter == 'all'
        ? all
        : all.where((a) => a.status == _filter).toList();

    final presentCount = all.where((a) => a.status == 'present').length;
    final lateCount = all.where((a) => a.status == 'late').length;
    final absentCount = all.where((a) => a.status == 'absent').length;
    final rate = all.isEmpty ? 0.0 : (presentCount + lateCount) / all.length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _GlowOrb(color: AppTheme.coral, size: 260, opacity: 0.06)),
          Positioned(bottom: 150, left: -80, child: _GlowOrb(color: AppTheme.cyan, size: 240, opacity: 0.05)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: ShaderMask(
                    shaderCallback: (b) => AppTheme.coralGradient.createShader(b),
                    child: Text('Mes Présences',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 20),

                // Stats cards row
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _StatCard(label: 'Présent', count: presentCount, total: all.length, color: AppTheme.success),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Retard', count: lateCount, total: all.length, color: AppTheme.warning),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Absent', count: absentCount, total: all.length, color: AppTheme.danger),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 16),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.88),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('Taux de présence',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                                const Spacer(),
                                ShaderMask(
                                  shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                                  child: Text('${(rate * 100).toStringAsFixed(1)}%',
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white.withValues(alpha: 0.90),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: rate.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: [BoxShadow(
                                        color: AppTheme.cyan.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      )],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 16),

                // Filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _FilterChip(label: 'Tous', value: 'all', selected: _filter == 'all',
                          color: AppTheme.cyan, onTap: () => setState(() => _filter = 'all')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Présent', value: 'present', selected: _filter == 'present',
                          color: AppTheme.success, onTap: () => setState(() => _filter = 'present')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Retard', value: 'late', selected: _filter == 'late',
                          color: AppTheme.warning, onTap: () => setState(() => _filter = 'late')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Absent', value: 'absent', selected: _filter == 'absent',
                          color: AppTheme.danger, onTap: () => setState(() => _filter = 'absent')),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 12),

                // List
                Expanded(
                  child: attendanceState.isLoading
                      ? const Center(child: LoadingIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.document_text, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.4)),
                                  const SizedBox(height: 14),
                                  Text('Aucune présence',
                                      style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textTertiary)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AttendanceTile(attendance: filtered[i]),
                              ),
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

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _StatCard({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: color.withValues(alpha: 0.07),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$count / $total',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.88),
          border: Border.all(color: selected ? color.withValues(alpha: 0.4) : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

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
        gradient: RadialGradient(colors: [color.withValues(alpha: opacity), Colors.transparent]),
      ),
    );
  }
}
