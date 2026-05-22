import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

// ─── Écran Justification d'absence ────────────────────────────────────────────

class JustificationScreen extends ConsumerStatefulWidget {
  const JustificationScreen({super.key});

  @override
  ConsumerState<JustificationScreen> createState() =>
      _JustificationScreenState();
}

class _JustificationScreenState extends ConsumerState<JustificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbCtl;

  final _formKey     = GlobalKey<FormState>();
  final _reasonCtl   = TextEditingController();
  final _dateCtl     = TextEditingController();
  final _imagePicker = ImagePicker();

  String _selectedType = 'medical';
  File?  _attachment;
  bool   _submitting   = false;
  bool   _submitted    = false;

  static const _types = [
    _JustType('medical',   '🏥', 'Médical',   AppTheme.success),
    _JustType('family',    '👨‍👩‍👧', 'Familial',  AppTheme.warning),
    _JustType('transport', '🚌', 'Transport', AppTheme.cyan),
    _JustType('other',     '📝', 'Autre',     AppTheme.violet),
  ];

  @override
  void initState() {
    super.initState();
    _orbCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    _dateCtl.text =
        '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}';
  }

  @override
  void dispose() {
    _orbCtl.dispose();
    _reasonCtl.dispose();
    _dateCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 80);
    if (picked != null) setState(() => _attachment = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final user = ref.read(authProvider).user;
      final api  = ApiClient();
      final uId  = user?.universityId ?? 0;
      final sId  = user?.studentId   ?? 0;

      final Map<String, dynamic> body = {
        'type':   _selectedType,
        'reason': _reasonCtl.text.trim(),
        'date':   _dateCtl.text.trim(),
      };

      if (_attachment != null) {
        body['document'] = await MultipartFile.fromFile(
          _attachment!.path,
          filename: 'justificatif.jpg',
        );
        await api.dio.post(
          '/universities/$uId/students/$sId/justifications',
          data: FormData.fromMap(body),
        );
      } else {
        await api.dio.post(
          '/universities/$uId/students/$sId/justifications',
          data: body,
        );
      }

      if (mounted) setState(() { _submitting = false; _submitted = true; });
      HapticFeedback.heavyImpact();
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'envoi. Vérifiez votre connexion.',
                style: GoogleFonts.inter()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // ── Orbes décoratifs ──
          AnimatedBuilder(
            animation: _orbCtl,
            builder: (_, __) {
              final a = _orbCtl.value * 2 * math.pi;
              return Stack(children: [
                Positioned(
                  top: -40 + math.sin(a) * 15,
                  left: -60,
                  child: _GlowOrb(color: AppTheme.cyan, size: 260, opacity: 0.06),
                ),
                Positioned(
                  bottom: 100 + math.cos(a) * 20,
                  right: -50,
                  child: _GlowOrb(color: AppTheme.violet, size: 220, opacity: 0.05),
                ),
              ]);
            },
          ),

          SafeArea(
            child: _submitted
                ? _SuccessView()
                : _FormView(
                    formKey:       _formKey,
                    reasonCtl:     _reasonCtl,
                    dateCtl:       _dateCtl,
                    types:         _types,
                    selectedType:  _selectedType,
                    attachment:    _attachment,
                    submitting:    _submitting,
                    onTypeChanged: (t) => setState(() => _selectedType = t),
                    onPickCamera:  () => _pickImage(ImageSource.camera),
                    onPickGallery: () => _pickImage(ImageSource.gallery),
                    onRemoveFile:  () => setState(() => _attachment = null),
                    onSubmit:      _submit,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Vue formulaire ───────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController reasonCtl;
  final TextEditingController dateCtl;
  final List<_JustType> types;
  final String selectedType;
  final File? attachment;
  final bool submitting;
  final void Function(String) onTypeChanged;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemoveFile;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.reasonCtl,
    required this.dateCtl,
    required this.types,
    required this.selectedType,
    required this.attachment,
    required this.submitting,
    required this.onTypeChanged,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemoveFile,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final activeType = types.firstWhere((t) => t.id == selectedType);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── AppBar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
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
              Expanded(
                child: ShaderMask(
                  shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                  child: Text(
                    'Justification d\'absence',
                    style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
            ]),
          ).animate().fadeIn(duration: 400.ms),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Type ──
                  _SectionLabel('Type d\'absence'),
                  const SizedBox(height: 10),
                  Row(
                    children: types.map((t) {
                      final active = t.id == selectedType;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTypeChanged(t.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: active
                                  ? t.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: active
                                    ? t.color.withValues(alpha: 0.40)
                                    : AppTheme.cardBorder,
                                width: active ? 1.5 : 1,
                              ),
                            ),
                            child: Column(children: [
                              Text(t.emoji,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(t.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? t.color
                                        : AppTheme.textTertiary,
                                  )),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // ── Date ──
                  _SectionLabel('Date de l\'absence'),
                  const SizedBox(height: 10),
                  _GlassField(
                    controller: dateCtl,
                    hint: 'JJ/MM/AAAA',
                    icon: Iconsax.calendar_1,
                    keyboardType: TextInputType.datetime,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Date requise' : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Motif ──
                  _SectionLabel('Motif détaillé'),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: TextFormField(
                          controller: reasonCtl,
                          maxLines: 4,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText:
                                'Décrivez brièvement la raison de votre absence...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 13, color: AppTheme.textTertiary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          validator: (v) => v == null || v.trim().length < 10
                              ? 'Minimum 10 caractères'
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Pièce jointe ──
                  _SectionLabel('Pièce justificative (optionnel)'),
                  const SizedBox(height: 10),
                  if (attachment == null) ...[
                    Row(children: [
                      Expanded(
                        child: _AttachButton(
                          icon: Iconsax.camera,
                          label: 'Caméra',
                          onTap: onPickCamera,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AttachButton(
                          icon: Iconsax.gallery,
                          label: 'Galerie',
                          onTap: onPickGallery,
                        ),
                      ),
                    ]),
                  ] else ...[
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(attachment!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: onRemoveFile,
                          child: Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.danger),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 32),

                  // ── Bouton envoyer ──
                  GestureDetector(
                    onTap: submitting ? null : onSubmit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: submitting
                            ? const LinearGradient(colors: [
                                Color(0xFF4B5563),
                                Color(0xFF6B7280)
                              ])
                            : LinearGradient(
                                colors: [activeType.color, AppTheme.violet]),
                        boxShadow: submitting
                            ? []
                            : [
                                BoxShadow(
                                  color: activeType.color
                                      .withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: submitting
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.send_2,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('Envoyer la justification',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 500.ms),
        ),
      ],
    );
  }
}

// ─── Vue succès ───────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [AppTheme.success, AppTheme.cyan]),
              ),
              child: const Icon(Iconsax.tick_circle,
                  size: 46, color: Colors.white),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Justification envoyée !',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                    textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            Text(
              'Votre demande a été transmise à l\'administration. '
              'Vous serez notifié(e) de la décision.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppTheme.primaryGradient,
                ),
                child: Text('Retour',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary));
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textTertiary),
              prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(children: [
            Icon(icon, size: 24, color: AppTheme.cyan),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ]),
        ),
      );
}

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

// ─── Modèle ───────────────────────────────────────────────────────────────────

class _JustType {
  final String id;
  final String emoji;
  final String label;
  final Color color;
  const _JustType(this.id, this.emoji, this.label, this.color);
}
