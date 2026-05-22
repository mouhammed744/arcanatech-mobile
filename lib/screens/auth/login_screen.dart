import 'dart:math' as math;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

const _kBlue      = Color(0xFF2563EB);
const _kBlueDark  = Color(0xFF1D4ED8);
const _kBlueDeep  = Color(0xFF1E3A8A);
const _kBorder    = Color(0xFFE5E7EB);
const _kText      = Color(0xFF111827);
const _kTextSub   = Color(0xFF6B7280);
const _kTextMuted = Color(0xFF9CA3AF);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtl   = TextEditingController();
  final _passCtl    = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();
  bool _obscure     = true;
  bool _remember    = false;
  bool _emailFocused = false;
  bool _passFocused  = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passFocus .addListener(() => setState(() => _passFocused  = _passFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtl.dispose(); _passCtl.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).login(_emailCtl.text.trim(), _passCtl.text);
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/home');
  }

  Future<void> _socialLogin(String provider) async {
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).socialLogin(provider);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.needsProfileCompletion) {
      context.go('/complete-profile', extra: {
        'name': auth.socialName ?? '', 'email': auth.socialEmail ?? '',
      });
    } else if (auth.isAuthenticated) {
      context.go('/home');
    }
  }

  Future<void> _showForgotPassword() async {
    final emailCtl  = TextEditingController();
    final emailFocus = FocusNode();
    bool sending = false;
    bool sent    = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: _kBorder))),
                const SizedBox(height: 20),
                if (!sent) ...[
                  Text('Mot de passe oublié',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 6),
                  Text("Saisis ton email — on t'envoie un lien.",
                    style: GoogleFonts.inter(fontSize: 14, color: _kTextSub, height: 1.5)),
                  const SizedBox(height: 20),
                  _AppField(
                    controller: emailCtl, focusNode: emailFocus, isFocused: false,
                    label: 'Adresse e-mail', hint: 'prenom.nom@email.com', icon: Iconsax.sms,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _PrimaryButton(
                    label: 'Envoyer le lien', isLoading: sending,
                    onTap: sending ? null : () async {
                      if (emailCtl.text.trim().isEmpty) return;
                      set(() => sending = true);
                      try {
                        await ref.read(authProvider.notifier).sendForgotPassword(emailCtl.text.trim());
                        set(() { sending = false; sent = true; });
                      } catch (_) { set(() => sending = false); }
                    },
                  ),
                ] else ...[
                  Center(child: Column(children: [
                    Container(width: 64, height: 64,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD1FAE5)),
                      child: const Icon(Iconsax.tick_circle, color: Color(0xFF059669), size: 30)),
                    const SizedBox(height: 16),
                    Text('Email envoyé !',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _kText)),
                    const SizedBox(height: 8),
                    Text('Vérifie ta boîte mail et clique\nsur le lien de réinitialisation.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: _kTextSub, height: 1.5)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF9FAFB), border: Border.all(color: _kBorder)),
                        child: Text('Fermer',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
                      ),
                    ),
                  ])),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    emailCtl.dispose();
    emailFocus.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: Column(
          children: [

            // ── Brand Header ─────────────────────────────────────────────────
            SizedBox(
              height: size.height * 0.36,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kBlueDeep, _kBlue],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(top: -60, right: -60,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05)))),
                  Positioned(bottom: -40, left: -30,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04)))),
                  SafeArea(
                    bottom: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76, height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 24, offset: const Offset(0, 8))],
                            ),
                            child: ClipOval(
                              child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(begin: const Offset(0.8, 0.8)),
                          const SizedBox(height: 14),
                          Text('ARCANA TECH',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 2.5))
                              .animate().fadeIn(delay: 120.ms),
                          const SizedBox(height: 5),
                          Text('Espace Étudiant',
                            style: GoogleFonts.inter(fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.72)))
                              .animate().fadeIn(delay: 180.ms),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, 28, 24, math.max(bottom + 24, 28)),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connexion',
                          style: GoogleFonts.inter(
                            fontSize: 24, fontWeight: FontWeight.w800, color: _kText)),
                        const SizedBox(height: 4),
                        Text('Accédez à votre espace étudiant',
                          style: GoogleFonts.inter(fontSize: 14, color: _kTextSub)),
                        const SizedBox(height: 24),

                        if (auth.error != null) ...[
                          _ErrorBanner(message: auth.error!)
                              .animate()
                              .fadeIn(duration: 250.ms)
                              .shake(hz: 3, offset: const Offset(4, 0)),
                          const SizedBox(height: 16),
                        ],

                        _AppField(
                          controller: _emailCtl, focusNode: _emailFocus,
                          isFocused: _emailFocused, label: 'Adresse e-mail',
                          hint: 'prenom.nom@email.com', icon: Iconsax.sms,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email requis';
                            if (!v.contains('@')) return 'Email invalide';
                            return null;
                          },
                        ).animate().fadeIn(delay: 80.ms),
                        const SizedBox(height: 16),

                        _AppField(
                          controller: _passCtl, focusNode: _passFocus,
                          isFocused: _passFocused, label: 'Mot de passe',
                          hint: '••••••••', icon: Iconsax.lock,
                          isPassword: true, obscure: _obscure,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Mot de passe requis';
                            return null;
                          },
                        ).animate().fadeIn(delay: 120.ms),
                        const SizedBox(height: 16),

                        Row(children: [
                          GestureDetector(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: _remember ? _kBlue : Colors.transparent,
                                  border: Border.all(
                                    color: _remember ? _kBlue : const Color(0xFFD1D5DB),
                                    width: 1.5),
                                ),
                                child: _remember
                                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text('Se souvenir de moi',
                                style: GoogleFonts.inter(fontSize: 13, color: _kTextSub)),
                            ]),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showForgotPassword,
                            child: Text('Mot de passe oublié ?',
                              style: GoogleFonts.inter(
                                fontSize: 13, color: _kBlue, fontWeight: FontWeight.w600)),
                          ),
                        ]).animate().fadeIn(delay: 160.ms),
                        const SizedBox(height: 28),

                        _PrimaryButton(
                          label: 'Se connecter',
                          isLoading: auth.isLoading,
                          onTap: auth.isLoading ? null : _login,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 24),

                        Row(children: [
                          Expanded(child: Container(height: 1, color: _kBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('ou continuer avec',
                              style: GoogleFonts.inter(fontSize: 12, color: _kTextMuted))),
                          Expanded(child: Container(height: 1, color: _kBorder)),
                        ]).animate().fadeIn(delay: 240.ms),
                        const SizedBox(height: 14),

                        _SocialButton(
                          onTap: () => _socialLogin('google'),
                          icon: SvgPicture.string(_kGoogleSvg, width: 20, height: 20),
                          label: 'Continuer avec Google',
                        ).animate().fadeIn(delay: 260.ms),
                        const SizedBox(height: 10),
                        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                          _SocialButton(
                            onTap: () => _socialLogin('apple'),
                            icon: SvgPicture.string(_kAppleSvg, width: 18, height: 20),
                            label: 'Continuer avec Apple',
                          ).animate().fadeIn(delay: 280.ms),
                          const SizedBox(height: 10),
                        ],
                        _SocialButton(
                          onTap: () => _socialLogin('tiktok'),
                          icon: SvgPicture.string(_kTikTokSvg, width: 18, height: 20),
                          label: 'Continuer avec TikTok',
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Pas encore de compte ?  ",
                              style: GoogleFonts.inter(fontSize: 14, color: _kTextSub)),
                            GestureDetector(
                              onTap: () => context.go('/register'),
                              child: Text("S'inscrire",
                                style: GoogleFonts.inter(
                                  fontSize: 14, color: _kBlue, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ).animate().fadeIn(delay: 340.ms),
                      ],
                    ),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFFEF2F2),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(children: [
      const Icon(Iconsax.warning_2, color: Color(0xFFEF4444), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
        style: GoogleFonts.inter(
          color: const Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _AppField({
    required this.controller, required this.focusNode, required this.isFocused,
    required this.label, required this.hint, required this.icon,
    this.keyboardType, this.textInputAction,
    this.isPassword = false, this.obscure = false,
    this.onToggleObscure, this.validator, this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isFocused ? _kBlue : const Color(0xFF374151),
          letterSpacing: 0.2),
        child: Text(label),
      ),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(
            color: isFocused ? _kBlue : _kBorder,
            width: isFocused ? 1.5 : 1.0),
          boxShadow: isFocused
              ? [BoxShadow(color: _kBlue.withValues(alpha: 0.10),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: TextFormField(
          controller: controller, focusNode: focusNode,
          keyboardType: keyboardType, textInputAction: textInputAction,
          obscureText: isPassword && obscure, onFieldSubmitted: onSubmitted,
          onTap: () => controller.selection =
              TextSelection.fromPosition(TextPosition(offset: controller.text.length)),
          style: GoogleFonts.inter(color: _kText, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 15),
            prefixIcon: Icon(icon, size: 19,
              color: isFocused ? _kBlue : _kTextMuted),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscure ? Iconsax.eye_slash : Iconsax.eye,
                      color: _kTextMuted, size: 19),
                    onPressed: onToggleObscure)
                : null,
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none, errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            errorStyle: GoogleFonts.inter(color: AppTheme.danger, fontSize: 11, height: 1.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            isDense: true,
          ),
          validator: validator,
        ),
      ),
    ],
  );
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.isLoading, this.onTap});
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:   disabled ? null : (_) { setState(() => _pressed = false); widget.onTap!(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity, height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: disabled ? null
                : const LinearGradient(
                    colors: [_kBlue, _kBlueDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
            color: disabled ? const Color(0xFFBFDBFE) : null,
            boxShadow: disabled ? null : [
              BoxShadow(color: _kBlue.withValues(alpha: 0.30),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;
  const _SocialButton({required this.onTap, required this.icon, required this.label});
  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: widget.icon),
            const SizedBox(width: 10),
            Text(widget.label,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
          ],
        ),
      ),
    ),
  );
}

// ── SVG Icons ─────────────────────────────────────────────────────────────────
const _kGoogleSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 533.5 544.3"><path fill="#4285f4" d="M533.5 278.4c0-18.5-1.5-37.1-4.7-55.3H272.1v104.8h147c-6.1 33.8-25.7 63.7-54.4 82.7v68h87.7c51.5-47.4 81.1-117.4 81.1-200.2z"/><path fill="#34a853" d="M272.1 544.3c73.4 0 135.3-24.1 180.4-65.7l-87.7-68c-24.4 16.6-55.9 26-92.6 26-71 0-131.2-47.9-152.8-112.3H28.9v70.1c46.2 91.9 140.3 149.9 243.2 149.9z"/><path fill="#fbbc04" d="M119.3 324.3c-11.4-33.8-11.4-70.4 0-104.2V150H28.9c-38.6 76.9-38.6 167.5 0 244.4l90.4-70.1z"/><path fill="#ea4335" d="M272.1 107.7c38.8-.6 76.3 14 104.4 40.8l77.7-77.7C405 24.6 339.7-.8 272.1 0 169.2 0 75.1 58 28.9 150l90.4 70.1c21.5-64.5 81.8-112.4 152.8-112.4z"/></svg>''';
const _kAppleSvg  = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 814 1000"><path fill="#000000" d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 790.9 0 663.1 0 541.8 0 347.4 100.3 244.6 194.3 194.1c57.8-31.9 134.1-51.9 204.4-51.9 71 0 134.4 27.2 180.7 27.2 44.5 0 113.5-29.2 188.3-29.2 23.7 0 99.3 2.9 152.5 48.2zm-103-192.8c-25.3 33.9-66.5 59-105.1 59-1.9 0-4.2-.3-6.1-.6-1.3-23.7 8.7-49.7 26.7-70.3 23.1-27.5 67-49 100.4-49 1.9 0 4.2.3 5.8.6 1.5 24.4-6.5 48-21.7 60.3z"/></svg>''';
const _kTikTokSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="#69C9D0" d="M448 209.9a210.1 210.1 0 0 1-122.8-39.3V349.4A162.6 162.6 0 1 1 185 188.3V278.2a74.6 74.6 0 1 0 52.2 71.2V0l88 0a121.2 121.2 0 0 0 1.9 22.2h0A122.2 122.2 0 0 0 381 102.4a121.4 121.4 0 0 0 67 20.1z"/><path fill="#EE1D52" d="M448 209.9a210.1 210.1 0 0 1-122.8-39.3V349.4A162.6 162.6 0 1 1 185 188.3V278.2a74.6 74.6 0 1 0 52.2 71.2V0l88 0a121.2 121.2 0 0 0 1.9 22.2h0A122.2 122.2 0 0 0 381 102.4z"/><path fill="#010101" d="M448 209.9a210.1 210.1 0 0 1-122.8-39.3V349.4A162.6 162.6 0 1 1 185 188.3V278.2a74.6 74.6 0 1 0 52.2 71.2V0l88 0a121.2 121.2 0 0 0 1.9 22.2h0A122.2 122.2 0 0 0 381 102.4a121.4 121.4 0 0 0 67 20.1z"/></svg>''';
