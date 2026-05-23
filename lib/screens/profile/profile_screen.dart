import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';

// ─── Shared shadow ────────────────────────────────────────────────────────────
const _kCardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(studentProvider.notifier).loadStats());
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85);
    if (image != null) {
      ref.read(authProvider.notifier).updateAvatar(image.path);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Déconnexion',
        message: 'Êtes-vous sûr de vouloir vous déconnecter ?',
        confirmLabel: 'Déconnexion',
        confirmColor: AppTheme.danger,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final studentState = ref.watch(studentProvider);
    final initial = user?.firstName.isNotEmpty == true
        ? user!.firstName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Profile header card (gradient) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative background circle
                      Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            // Avatar
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 86,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withValues(alpha: 0.18),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                          width: 2.5),
                                    ),
                                    child: Center(
                                      child: Text(initial,
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 32)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                            color: const Color(0xFF2563EB),
                                            width: 1.5),
                                      ),
                                      child: const Icon(Iconsax.camera,
                                          size: 12,
                                          color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user?.fullName ?? 'Étudiant',
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            if (user?.filiere != null)
                              Text(
                                user!.filiere!,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        Colors.white.withValues(alpha: 0.70),
                                    fontWeight: FontWeight.w500),
                              ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color:
                                    Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                'N° ${user?.registrationNumber ?? 'N/A'}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ── Quick actions grid ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                        child: _QuickAction(
                            icon: Iconsax.book_1,
                            label: 'MES COURS',
                            color: AppTheme.cyan,
                            onTap: () => context.push('/schedule'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _QuickAction(
                            icon: Iconsax.clock,
                            label: 'PRÉSENCES',
                            color: AppTheme.violet,
                            onTap: () => context.push('/attendance'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _QuickAction(
                            icon: Iconsax.document_upload,
                            label: 'JUSTIFIER',
                            color: AppTheme.coral,
                            onTap: () => context.push('/justification'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _QuickAction(
                            icon: Iconsax.setting_2,
                            label: 'PARAMÈTRES',
                            color: AppTheme.success,
                            onTap: () => context.push('/settings'))),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

              const SizedBox(height: 20),

              // ── Carte étudiant ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('CARTE ÉTUDIANT'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                        border: Border.all(
                            color:
                                AppTheme.violet.withValues(alpha: 0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.violet.withValues(alpha: 0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user?.filiere != null)
                                  _CardRow(
                                      icon: Iconsax.code_circle,
                                      label: 'Filière',
                                      value: user!.filiere!),
                                if (user?.level != null) ...[
                                  const SizedBox(height: 10),
                                  _CardRow(
                                      icon: Iconsax.ranking_1,
                                      label: 'Niveau',
                                      value: user!.level!),
                                ],
                                if (user?.university != null) ...[
                                  const SizedBox(height: 10),
                                  _CardRow(
                                      icon: Iconsax.building,
                                      label: 'Groupe',
                                      value: 'B'),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF2563EB)
                                ],
                              ),
                            ),
                            child: const Icon(Iconsax.barcode,
                                size: 26, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

              const SizedBox(height: 20),

              // ── Informations personnelles ──
              _InfoSection(
                title: 'INFORMATIONS',
                items: [
                  _InfoItem(
                      icon: Iconsax.sms,
                      label: 'Email',
                      value: user?.email ?? ''),
                  if (user?.phone != null)
                    _InfoItem(
                        icon: Iconsax.call,
                        label: 'Téléphone',
                        value: user!.phone!),
                  if (user?.registrationNumber != null)
                    _InfoItem(
                        icon: Iconsax.card,
                        label: 'Matricule',
                        value: user!.registrationNumber!),
                  if (user?.filiere != null)
                    _InfoItem(
                        icon: Iconsax.book_1,
                        label: 'Filière',
                        value: user!.filiere!),
                  if (user?.level != null)
                    _InfoItem(
                        icon: Iconsax.ranking_1,
                        label: 'Niveau',
                        value: user!.level!),
                ],
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),

              const SizedBox(height: 16),

              // ── Carte RFID ──
              if (studentState.stats?.rfidCard != null)
                _InfoSection(
                  title: 'CARTE RFID',
                  items: [
                    _InfoItem(
                        icon: Iconsax.card,
                        label: 'N° Carte',
                        value: studentState.stats!.rfidCard!.cardNumber),
                    _InfoItem(
                        icon: Iconsax.shield_tick,
                        label: 'Statut',
                        value: studentState.stats!.rfidCard!.statusLabel,
                        valueColor:
                            studentState.stats!.rfidCard!.isActive
                                ? AppTheme.success
                                : AppTheme.danger),
                  ],
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),

              const SizedBox(height: 20),

              // ── Boutons d'action ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Éditer profil',
                        icon: Iconsax.edit,
                        onTap: () {},
                        gradient: AppTheme.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Déconnexion',
                        icon: Iconsax.logout,
                        onTap: _confirmLogout,
                        color: AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 1.1)),
    );
  }
}

// ─── Quick action chip ────────────────────────────────────────────────────────

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.color, this.onTap});

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: widget.color.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.10),
                ),
                child: Icon(widget.icon, size: 19, color: widget.color),
              ),
              const SizedBox(height: 8),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info section card ────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _InfoSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: _kCardShadow,
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppTheme.divider)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.bg,
                        ),
                        child: Icon(item.icon,
                            size: 15,
                            color: AppTheme.textTertiary
                                .withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 12),
                      Text(item.label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textSecondary)),
                      const Spacer(),
                      Flexible(
                        child: Text(item.value,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: item.valueColor ??
                                    AppTheme.textPrimary),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card row ─────────────────────────────────────────────────────────────────

class _CardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CardRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 13,
            color: AppTheme.textTertiary.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textTertiary)),
        Flexible(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final Color? color;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.gradient,
      this.color});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppTheme.cyan;
    final isGradient = widget.gradient != null;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.gradient,
            color: isGradient ? null : c.withValues(alpha: 0.08),
            border: Border.all(
                color: isGradient
                    ? Colors.transparent
                    : c.withValues(alpha: 0.22)),
            boxShadow: isGradient
                ? [
                    BoxShadow(
                        color: AppTheme.cyan.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: isGradient ? Colors.white : c),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isGradient ? Colors.white : c)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info item data ───────────────────────────────────────────────────────────

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoItem(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _ConfirmDialog(
      {required this.title,
      required this.message,
      required this.confirmLabel,
      required this.confirmColor,
      required this.onConfirm,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppTheme.bgCard,
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: confirmColor.withValues(alpha: 0.10),
                  ),
                  child: Icon(Iconsax.logout,
                      size: 24, color: confirmColor),
                ),
                const SizedBox(height: 14),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.45)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.bg,
                            border:
                                Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Center(
                            child: Text('Annuler',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: confirmColor.withValues(alpha: 0.10),
                            border: Border.all(
                                color: confirmColor
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: Text(confirmLabel,
                                style: GoogleFonts.inter(
                                    color: confirmColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
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
    );
  }
}
