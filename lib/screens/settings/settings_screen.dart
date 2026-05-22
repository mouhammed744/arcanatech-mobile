import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

// ─── Écran Paramètres ─────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbCtl;

  // Préférences locales (seraient persistées en SharedPreferences)
  bool _notifSchedule  = true;
  bool _notifGrades    = true;
  bool _notifAttend    = true;
  String _language     = 'fr';

  @override
  void initState() {
    super.initState();
    _orbCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
  }

  @override
  void dispose() {
    _orbCtl.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Déconnexion',
        message: 'Voulez-vous vraiment vous déconnecter ?',
        confirmLabel: 'Déconnexion',
        confirmColor: AppTheme.danger,
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // ── Orbes ──
          AnimatedBuilder(
            animation: _orbCtl,
            builder: (_, __) {
              final a = _orbCtl.value * 2 * math.pi;
              return Stack(children: [
                Positioned(
                  top: -60 + math.sin(a) * 18,
                  right: -50,
                  child: _GlowOrb(color: AppTheme.violet, size: 280, opacity: 0.07),
                ),
                Positioned(
                  bottom: 120 + math.cos(a) * 15,
                  left: -60,
                  child: _GlowOrb(color: AppTheme.cyan, size: 240, opacity: 0.05),
                ),
              ]);
            },
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              size: 16, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: Text('Paramètres',
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                // ════════════════════════════════════════════
                // APPARENCE
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Apparence',
                    icon: Iconsax.sun_1,
                    color: AppTheme.warning,
                    children: [
                      _ToggleTile(
                        icon: isDark ? Iconsax.moon : Iconsax.sun_1,
                        iconColor: isDark ? AppTheme.violet : AppTheme.warning,
                        title: 'Mode sombre',
                        subtitle: isDark ? 'Activé' : 'Désactivé',
                        value: isDark,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          ref.read(themeProvider.notifier).toggleTheme();
                        },
                      ),
                    ],
                  ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ════════════════════════════════════════════
                // NOTIFICATIONS
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Notifications',
                    icon: Iconsax.notification,
                    color: AppTheme.cyan,
                    children: [
                      _ToggleTile(
                        icon: Iconsax.calendar_2,
                        iconColor: AppTheme.cyan,
                        title: 'Emploi du temps',
                        subtitle: 'Alertes de cours',
                        value: _notifSchedule,
                        onChanged: (v) =>
                            setState(() => _notifSchedule = v),
                      ),
                      _Separator(),
                      _ToggleTile(
                        icon: Iconsax.medal_star,
                        iconColor: AppTheme.violet,
                        title: 'Notes & résultats',
                        subtitle: 'Nouvelles notes publiées',
                        value: _notifGrades,
                        onChanged: (v) =>
                            setState(() => _notifGrades = v),
                      ),
                      _Separator(),
                      _ToggleTile(
                        icon: Iconsax.tick_circle,
                        iconColor: AppTheme.success,
                        title: 'Présences',
                        subtitle: 'Confirmations d\'appel',
                        value: _notifAttend,
                        onChanged: (v) =>
                            setState(() => _notifAttend = v),
                      ),
                    ],
                  ).animate().fadeIn(delay: 140.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ════════════════════════════════════════════
                // LANGUE
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Langue',
                    icon: Iconsax.language_square,
                    color: AppTheme.success,
                    children: [
                      _LangTile(
                        flag: '🇫🇷',
                        label: 'Français',
                        selected: _language == 'fr',
                        onTap: () =>
                            setState(() => _language = 'fr'),
                      ),
                      _Separator(),
                      _LangTile(
                        flag: '🇬🇧',
                        label: 'English',
                        selected: _language == 'en',
                        onTap: () =>
                            setState(() => _language = 'en'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ════════════════════════════════════════════
                // COMPTE
                // ════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Compte',
                    icon: Iconsax.user,
                    color: AppTheme.coral,
                    children: [
                      _ActionTile(
                        icon: Iconsax.logout,
                        iconColor: AppTheme.danger,
                        title: 'Se déconnecter',
                        subtitle: 'Fermer la session actuelle',
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        onTap: _confirmLogout,
                      ),
                    ],
                  ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Version ──
                SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      'ARCANA TECH · v1.0.0',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                          letterSpacing: 0.8),
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label de section
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(children: children),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile toggle ──────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: iconColor.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.cyan,
        ),
      ]),
    );
  }
}

// ─── Tile action ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

// ─── Tile langue ──────────────────────────────────────────────────────────────

class _LangTile extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
          if (selected)
            Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 14, color: Colors.white),
            ),
        ]),
      ),
    );
  }
}

// ─── Séparateur ───────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 68),
        color: AppTheme.cardBorder,
      );
}

// ─── Dialog confirmation ──────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w800)),
      content: Text(message,
          style: GoogleFonts.inter(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler',
              style: GoogleFonts.inter(color: AppTheme.textTertiary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: GoogleFonts.inter(
                  color: confirmColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Orbe ─────────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), Colors.transparent]),
        ),
      );
}
