import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/timetable_entry.dart';

class CourseCard extends StatelessWidget {
  final TimetableEntry course;
  const CourseCard({super.key, required this.course});

  bool _isNow() {
    try {
      final now = TimeOfDay.now();
      final sParts = course.startTime.split(':');
      final eParts = course.endTime.split(':');
      final startMins = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endMins = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final nowMins = now.hour * 60 + now.minute;
      return nowMins >= startMins && nowMins <= endMins;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _isNow();
    final accent = isLive ? AppTheme.coral : AppTheme.cyan;
    final teacher = course.teacherName ?? '';
    final room = course.roomName ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: accent.withValues(alpha: 0.05),
            border: Border.all(color: accent.withValues(alpha: isLive ? 0.25 : 0.12)),
            boxShadow: isLive
                ? [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: -2)]
                : null,
          ),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.4)],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Time column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(course.startTime,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
                  const SizedBox(height: 4),
                  Text(course.endTime,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                ],
              ),
              const SizedBox(width: 16),
              // Vertical divider
              Container(width: 1, height: 40, color: AppTheme.divider),
              const SizedBox(width: 16),
              // Course info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.courseName,
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: AppTheme.coral.withValues(alpha: 0.15),
                                border: Border.all(color: AppTheme.coral.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.coral,
                                      boxShadow: [BoxShadow(color: AppTheme.coral.withValues(alpha: 0.6), blurRadius: 4)]),
                                  ),
                                  const SizedBox(width: 5),
                                  Text('EN COURS',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800,
                                          color: AppTheme.coral, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (teacher.isNotEmpty) ...[
                            Icon(Iconsax.teacher, size: 13, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(teacher,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          if (room.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Iconsax.location, size: 13, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(room,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
