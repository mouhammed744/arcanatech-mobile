import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../providers/auth_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  final String name;
  final String email;

  const CompleteProfileScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  // ── Palette (identique au login) ─────────────────────────────────────────
  static const _blue     = Color(0xFF2563EB);
  static const _blueDark = Color(0xFF1D4ED8);

  // ── Contrôleurs ──────────────────────────────────────────────────────────
  final _formKey        = GlobalKey<FormState>();
  final _passwordCtl    = TextEditingController();
  final _confirmCtl     = TextEditingController();
  final _studentCardCtl = TextEditingController();
  final _phoneCtl       = TextEditingController();
  final _universityCtl  = TextEditingController();
  final _filiereCtl     = TextEditingController();

  // ── FocusNodes ───────────────────────────────────────────────────────────
  final _passwordFocus    = FocusNode();
  final _confirmFocus     = FocusNode();
  final _studentCardFocus = FocusNode();
  final _phoneFocus       = FocusNode();
  final _universityFocus  = FocusNode();
  final _filiereFocus     = FocusNode();

  bool _passwordFocused    = false;
  bool _confirmFocused     = false;
  bool _studentCardFocused = false;
  bool _phoneFocused       = false;
  bool _universityFocused  = false;
  bool _filiereFocused     = false;
  bool _obscurePass        = true;
  bool _obscureConfirm     = true;

  String? _niveau;
  static const _niveaux = ['L1', 'L2', 'L3', 'M1', 'M2', 'Doctorat'];

  @override
  void initState() {
    super.initState();
    _passwordFocus   .addListener(() => setState(() => _passwordFocused    = _passwordFocus.hasFocus));
    _confirmFocus    .addListener(() => setState(() => _confirmFocused     = _confirmFocus.hasFocus));
    _studentCardFocus.addListener(() => setState(() => _studentCardFocused = _studentCardFocus.hasFocus));
    _phoneFocus      .addListener(() => setState(() => _phoneFocused       = _phoneFocus.hasFocus));
    _universityFocus .addListener(() => setState(() => _universityFocused  = _universityFocus.hasFocus));
    _filiereFocus    .addListener(() => setState(() => _filiereFocused     = _filiereFocus.hasFocus));
  }

  @override
  void dispose() {
    _passwordCtl.dispose();    _confirmCtl.dispose();
    _studentCardCtl.dispose(); _phoneCtl.dispose();
    _universityCtl.dispose();  _filiereCtl.dispose();
    _passwordFocus.dispose();    _confirmFocus.dispose();
    _studentCardFocus.dispose(); _phoneFocus.dispose();
    _universityFocus.dispose();  _filiereFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_niveau == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez sélectionner votre niveau',
            style: GoogleFonts.inter()),
        backgroundColor: _blue,
      ));
      return;
    }
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).completeSocialProfile({
      'password'   : _passwordCtl.text,
      'studentCard': _studentCardCtl.text.trim(),
      'phone'      : _phoneCtl.text.trim(),
      'university' : _universityCtl.text.trim(),
      'filiere'    : _filiereCtl.text.trim(),
      'niveau'     : _niveau!,
    });
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final auth   = ref.watch(authProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── Fond blanc ──────────────────────────────────────────────
            Container(color: Colors.white),

            // ── Section bleue diagonale 45% (décalée vers la droite) ───
            Positioned.fill(
              child: ClipPath(
                clipper: _BlueTopClipper(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // ── Contenu ─────────────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom > 0 ? bottom + 16 : 32),
                child: Column(
                  children: [
                    // ── Zone bleue : icône + titre ─────────────────────
                    SizedBox(height: size.height * 0.04),

                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.50), width: 2),
                      ),
                      child: const Icon(Iconsax.user_edit, size: 32, color: Colors.white),
                    ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(0.8, 0.8)),

                    const SizedBox(height: 12),

                    Text(
                      'Complétez votre profil',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 4),

                    Text(
                      'Quelques infos pour finaliser votre inscription',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms),

                    SizedBox(height: size.height * 0.04),

                    // ── Carte blanche (même style login) ─────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // ── Nom (read-only, pill) ─────────────────
                              _ReadOnlyPill(
                                value: widget.name.isNotEmpty ? widget.name : 'Utilisateur',
                                icon: Iconsax.user,
                                hint: 'Nom complet',
                              ).animate().fadeIn(delay: 150.ms),
                              const SizedBox(height: 12),

                              // ── Email (read-only, pill) ───────────────
                              _ReadOnlyPill(
                                value: widget.email,
                                icon: Iconsax.sms,
                                hint: 'Email',
                              ).animate().fadeIn(delay: 200.ms),
                              const SizedBox(height: 12),

                              // ── Mot de passe ─────────────────────────
                              _GradientPill(
                                controller: _passwordCtl,
                                focusNode: _passwordFocus,
                                isFocused: _passwordFocused,
                                hint: 'Créer un mot de passe',
                                icon: Iconsax.lock,
                                isPassword: true,
                                obscure: _obscurePass,
                                onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  if (v.length < 8) return 'Minimum 8 caractères';
                                  return null;
                                },
                              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── Confirmer mot de passe ────────────────
                              _GradientPill(
                                controller: _confirmCtl,
                                focusNode: _confirmFocus,
                                isFocused: _confirmFocused,
                                hint: 'Confirmer le mot de passe',
                                icon: Iconsax.lock_1,
                                isPassword: true,
                                obscure: _obscureConfirm,
                                onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  if (v != _passwordCtl.text) return 'Les mots de passe ne correspondent pas';
                                  return null;
                                },
                              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── N° carte étudiant ─────────────────────
                              _GradientPill(
                                controller: _studentCardCtl,
                                focusNode: _studentCardFocus,
                                isFocused: _studentCardFocused,
                                hint: 'N° carte étudiant (ex: UAC-2024-001)',
                                icon: Iconsax.card,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── Téléphone ─────────────────────────────
                              _GradientPill(
                                controller: _phoneCtl,
                                focusNode: _phoneFocus,
                                isFocused: _phoneFocused,
                                hint: 'Téléphone (ex: +229 97 00 00 00)',
                                icon: Iconsax.call,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── Université ────────────────────────────
                              _GradientPill(
                                controller: _universityCtl,
                                focusNode: _universityFocus,
                                isFocused: _universityFocused,
                                hint: "Université (ex: UAC)",
                                icon: Iconsax.building,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── Filière ───────────────────────────────
                              _GradientPill(
                                controller: _filiereCtl,
                                focusNode: _filiereFocus,
                                isFocused: _filiereFocused,
                                hint: 'Filière (ex: Informatique)',
                                icon: Iconsax.book,
                                textInputAction: TextInputAction.done,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.04),
                              const SizedBox(height: 12),

                              // ── Niveau dropdown ───────────────────────
                              _NiveauDropdown(
                                value: _niveau,
                                items: _niveaux,
                                onChanged: (v) => setState(() => _niveau = v),
                              ).animate().fadeIn(delay: 550.ms),
                              const SizedBox(height: 24),

                              // ── Bouton Terminer ───────────────────────
                              GestureDetector(
                                onTap: auth.isLoading ? null : _submit,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      colors: [_blue, _blueDark],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _blue.withOpacity(0.40),
                                        blurRadius: 18,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            width: 22, height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : Text(
                                            'Terminer l\'inscription',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.04),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms, duration: 500.ms).slideY(begin: 0.06),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Champ lecture seule style pill avec dégradé ───────────────────────────────
class _ReadOnlyPill extends StatelessWidget {
  final String value;
  final IconData icon;
  final String hint;
  const _ReadOnlyPill({required this.value, required this.icon, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF93C5FD)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : hint,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: value.isNotEmpty
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Iconsax.lock, size: 14, color: Color(0xFFBFDBFE)),
        ],
      ),
    );
  }
}

// ── Champ pill avec dégradé bleu→blanc (identique au login) ──────────────────
class _GradientPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _GradientPill({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: isFocused
              ? [const Color(0xFF2563EB).withOpacity(0.13), Colors.white]
              : [const Color(0xFF3B82F6).withOpacity(0.07), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: isFocused ? const Color(0xFF93C5FD) : const Color(0xFFBFDBFE),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [BoxShadow(
                color: blue.withOpacity(0.10),
                blurRadius: 12,
              )]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: isPassword && obscure,
        validator: validator,
        style: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, size: 20,
              color: isFocused ? blue : const Color(0xFF93C5FD)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure ? Iconsax.eye_slash : Iconsax.eye,
                    size: 20,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ── Dropdown Niveau style pill ────────────────────────────────────────────────
class _NiveauDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  const _NiveauDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: value != null
              ? [const Color(0xFF2563EB).withOpacity(0.13), Colors.white]
              : [const Color(0xFF3B82F6).withOpacity(0.07), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
          color: value != null ? const Color(0xFF93C5FD) : const Color(0xFFBFDBFE),
          width: value != null ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              const Icon(Iconsax.award, size: 20, color: Color(0xFF93C5FD)),
              const SizedBox(width: 12),
              Text('Niveau d\'étude',
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8))),
            ],
          ),
          icon: Icon(Iconsax.arrow_down, size: 18,
              color: value != null ? blue : const Color(0xFF94A3B8)),
          isExpanded: true,
          style: GoogleFonts.inter(
              fontSize: 15, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: items.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Clipper diagonal 45% décalé à droite ────────────────────────────────────
class _BlueTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.52); // droite : 52 %
    path.lineTo(0, size.height * 0.38);           // gauche  : 38 %
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
