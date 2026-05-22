import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/attendance.dart';

class AttendanceTile extends StatelessWidget {
  final Attendance attendance;
  const AttendanceTile({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (attendance.status) {
      'present' => (AppTheme.success, Iconsax.tick_circle, 'Présent'),
      'late'    => (AppTheme.warning, Iconsax.clock,       'Retard'),
      _         => (AppTheme.danger,  Iconsax.close_circle,'Absent'),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.04),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendance.courseName ?? 'Cours',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(attendance.date,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(label,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
