import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _blue     = Color(0xFF2563EB);
const _blueDark = Color(0xFF1D4ED8);

// ── Étapes ───────────────────────────────────────────────────────────────────
class _StepInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  const _StepInfo(this.title, this.subtitle, this.icon);
}

const _steps = [
  _StepInfo('Identité',   'Informations personnelles & mot de passe', Iconsax.user),
  _StepInfo('Académique', 'Filière & niveau d\'étude',                Iconsax.teacher),
];

// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _firstNameCtl   = TextEditingController();
  final _lastNameCtl    = TextEditingController();
  final _emailCtl       = TextEditingController();
  final _phoneCtl       = TextEditingController();
  final _passCtl        = TextEditingController();
  final _confirmCtl     = TextEditingController();
  final _filiereCtl     = TextEditingController(); // fallback texte libre

  // FocusNodes
  final _lastNameFocus  = FocusNode();
  final _firstNameFocus = FocusNode();
  final _emailFocus     = FocusNode();
  final _phoneFocus     = FocusNode();
  final _passFocus      = FocusNode();
  final _confirmFocus   = FocusNode();
  final _filiereFocus   = FocusNode();

  bool _lastNameFocused  = false;
  bool _firstNameFocused = false;
  bool _emailFocused     = false;
  bool _phoneFocused     = false;
  bool _passFocused      = false;
  bool _confirmFocused   = false;
  bool _filiereFocused   = false;

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _error;
  DateTime? _birthDate;
  String? _selectedNiveau;
  int?    _selectedFiliereId;
  String? _selectedFiliereName;
  String? _generatedMatricule; // reçu du backend après inscription
  int _step = 0;

  // Université & filières chargées dynamiquement depuis l'API
  int?    _universityId;
  String  _universityName = '';
  List<Map<String, dynamic>> _filieresFromApi = [];
  bool _loadingFilieres = false;

  final _api = ApiClient();

  static const _niveaux = [
    'Licence 1', 'Licence 2', 'Licence 3',
    'Master 1', 'Master 2', 'Doctorat',
  ];

  @override
  void initState() {
    super.initState();
    _lastNameFocus .addListener(() => setState(() => _lastNameFocused  = _lastNameFocus.hasFocus));
    _firstNameFocus.addListener(() => setState(() => _firstNameFocused = _firstNameFocus.hasFocus));
    _emailFocus    .addListener(() => setState(() => _emailFocused     = _emailFocus.hasFocus));
    _phoneFocus    .addListener(() => setState(() => _phoneFocused     = _phoneFocus.hasFocus));
    _passFocus     .addListener(() => setState(() => _passFocused      = _passFocus.hasFocus));
    _confirmFocus  .addListener(() => setState(() => _confirmFocused   = _confirmFocus.hasFocus));
    _filiereFocus  .addListener(() => setState(() => _filiereFocused   = _filiereFocus.hasFocus));
    _passCtl   .addListener(() => setState(() {}));
    _confirmCtl.addListener(() => setState(() {}));
    // Charger l'université puis les filières depuis l'API
    _loadUniversityAndFilieres();
  }

  /// Récupère la première université disponible puis charge ses filières
  Future<void> _loadUniversityAndFilieres() async {
    setState(() { _loadingFilieres = true; _filieresFromApi = []; });
    try {
      // 1. Récupérer la liste des universités
      final uResp = await _api.dio.get(ApiEndpoints.universities);
      final uList = (uResp.data['data'] as List?) ?? [];
      if (uList.isEmpty) {
        if (mounted) setState(() => _loadingFilieres = false);
        return;
      }
      // Chercher LCS (code "LCS"), sinon prendre la première
      final uData = uList.firstWhere(
        (u) => (u['code'] as String? ?? '').toUpperCase() == 'LCS',
        orElse: () => uList.first,
      ) as Map<String, dynamic>;
      final uId   = uData['id'] as int;
      final uName = uData['name'] as String? ?? '';
      if (mounted) setState(() { _universityId = uId; _universityName = uName; });

      // 2. Charger les filières pour cette université
      final fResp = await _api.dio.get(ApiEndpoints.filieresPublic(uId));
      final fList = (fResp.data['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _filieresFromApi = fList
              .map((f) => {'id': f['id'], 'name': f['name'], 'code': f['code']})
              .toList();
        });
      }
    } catch (_) {
      // Pas de filières disponibles — champ texte libre en fallback
    } finally {
      if (mounted) setState(() => _loadingFilieres = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtl.dispose(); _lastNameCtl.dispose();
    _emailCtl.dispose();     _phoneCtl.dispose();
    _passCtl.dispose();      _confirmCtl.dispose();
    _filiereCtl.dispose();
    _lastNameFocus.dispose(); _firstNameFocus.dispose();
    _emailFocus.dispose();    _phoneFocus.dispose();
    _passFocus.dispose();     _confirmFocus.dispose();
    _filiereFocus.dispose();
    super.dispose();
  }



  bool _validate() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_lastNameCtl.text.trim().isEmpty || _firstNameCtl.text.trim().isEmpty) {
        setState(() => _error = 'Nom et prénom requis'); return false;
      }
      if (_birthDate == null) {
        setState(() => _error = 'Date de naissance requise'); return false;
      }
      if (_emailCtl.text.trim().isEmpty || !_emailCtl.text.contains('@')) {
        setState(() => _error = 'Email valide requis'); return false;
      }
      if (_passCtl.text.length < 8) {
        setState(() => _error = 'Mot de passe : 8 caractères minimum'); return false;
      }
      if (_passCtl.text != _confirmCtl.text) {
        setState(() => _error = 'Les mots de passe ne correspondent pas'); return false;
      }
    } else if (_step == 1) {
      // Filière : soit sélectionnée dans dropdown, soit saisie manuellement
      final hasFiliere = _selectedFiliereId != null || _filiereCtl.text.trim().isNotEmpty;
      if (!hasFiliere) {
        setState(() => _error = 'Veuillez sélectionner votre filière'); return false;
      }
    }
    return true;
  }

  void _next() {
    if (!_validate()) return;
    HapticFeedback.lightImpact();
    if (_step < _steps.length - 1) setState(() => _step++);
  }

  void _prev() {
    if (_step > 0) {
      HapticFeedback.lightImpact();
      setState(() { _step--; _error = null; });
    }
  }

  // Mapping niveau affiché → valeur backend
  static const _niveauValues = {
    'Licence 1': 'L1',
    'Licence 2': 'L2',
    'Licence 3': 'L3',
    'Master 1' : 'M1',
    'Master 2' : 'M2',
    'Doctorat' : 'D',
  };

  Future<void> _register() async {
    if (!_validate()) return;
    HapticFeedback.mediumImpact();
    setState(() { _isLoading = true; _error = null; });
    try {
      final niveauBackend = _niveauValues[_selectedNiveau] ?? _selectedNiveau ?? 'L1';

      final fd = FormData.fromMap({
        'first_name'            : _firstNameCtl.text.trim(),
        'last_name'             : _lastNameCtl.text.trim(),
        'email'                 : _emailCtl.text.trim(),
        'phone'                 : _phoneCtl.text.trim(),
        'password'              : _passCtl.text,
        'password_confirmation' : _confirmCtl.text,
        if (_birthDate != null)
          'birth_date': '${_birthDate!.year.toString().padLeft(4,'0')}-'
                        '${_birthDate!.month.toString().padLeft(2,'0')}-'
                        '${_birthDate!.day.toString().padLeft(2,'0')}',
        'filiere'               : _selectedFiliereName ?? _filiereCtl.text.trim(),
        if (_selectedFiliereId != null) 'filiere_id': _selectedFiliereId.toString(),
        if (_universityId != null) 'university_id': _universityId.toString(),
        'level'                 : niveauBackend,
      });
      final response = await _api.dio.post(ApiEndpoints.registerStudent, data: fd);

      // Récupérer le matricule généré par le backend
      final matricule = response.data?['registration_number'] as String?;
      if (matricule != null) {
        setState(() => _generatedMatricule = matricule);
      }
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (e is DioException) {
        var msg = "Erreur de connexion au serveur. Vérifiez votre réseau.";
        if (e.response?.data is Map) {
          final d = e.response!.data as Map<String, dynamic>;
          if (d['message'] != null) {
            msg = d['message'] as String;
          } else if (d['errors'] != null) {
            msg = (d['errors'] as Map<String, dynamic>)
                .values.expand((x) => x as List).join('\n');
          }
        }
        if (mounted) setState(() => _error = msg);
      } else {
        if (mounted) setState(() => _error = "Une erreur inattendue est survenue. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Iconsax.tick_circle, color: Colors.white, size: 36),
                ).animate().scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 20),
                Text('Compte créé !',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  )),
                const SizedBox(height: 10),
                Text(
                  'Votre compte a été créé avec succès.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  )),
                if (_generatedMatricule != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFEFF6FF),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      children: [
                        Text('Votre matricule', style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600, letterSpacing: 0.5,
                        )),
                        const SizedBox(height: 4),
                        Text(_generatedMatricule!, style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: const Color(0xFF1D4ED8),
                          letterSpacing: 2,
                        )),
                        const SizedBox(height: 4),
                        Text('Notez-le précieusement', style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B),
                        )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () { Navigator.pop(ctx); context.go('/login'); },
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _blue,
                      boxShadow: [
                        BoxShadow(
                          color: _blue.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('Se connecter',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build principal ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ── Gradient header ──
            _buildGradientHeader(),

            // ── White form area ──
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 20, right: 20,
                    bottom: bottom > 0 ? bottom + 16 : 24,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Error banner
                      if (_error != null) ...[
                        _ErrorPill(message: _error!)
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .shake(hz: 3, offset: const Offset(4, 0)),
                        const SizedBox(height: 12),
                      ],

                      // Form
                      Form(
                        key: _formKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: [_step1(), _step2()][_step],
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                      const SizedBox(height: 20),

                      // Action button
                      _buildActionButton(),
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

  // ── Gradient header with step indicator ─────────────────────────────────────
  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _step > 0 ? _prev() : context.go('/login'),
                    icon: Icon(
                      _step > 0 ? Iconsax.arrow_left_2 : Iconsax.close_circle,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ÉTAPE ${_step + 1}/${_steps.length} · ${_steps[_step].title}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _steps[_step].subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Step icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                    ),
                    child: Icon(_steps[_step].icon, size: 20, color: Colors.white),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // Step progress pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: List.generate(_steps.length, (i) {
                    final done = i <= _step;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: done
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                          if (i < _steps.length - 1)
                            const SizedBox(width: 6),
                        ],
                      ),
                    );
                  }),
                ),
              ).animate().fadeIn(delay: 100.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action button ────────────────────────────────────────────────────────────
  Widget _buildActionButton() {
    final isLast = _step == _steps.length - 1;
    return GestureDetector(
      onTap: _isLoading ? null : (isLast ? _register : _next),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isLast ? const Color(0xFF16A34A) : _blue,
          boxShadow: [
            BoxShadow(
              color: (isLast ? const Color(0xFF22C55E) : _blue).withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'CRÉER MON COMPTE' : 'SUIVANT',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Iconsax.arrow_right_3, size: 18, color: Colors.white),
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04);
  }

  // ── ÉTAPE 1 : Identité + Mot de passe ───────────────────────────────────────
  Widget _step1() {
    return Column(
      children: [
        _AppField(
          label: 'Nom de famille',
          hint: 'Votre nom',
          icon: Iconsax.user,
          controller: _lastNameCtl,
          focusNode: _lastNameFocus,
          isFocused: _lastNameFocused,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _AppField(
          label: 'Prénom',
          hint: 'Votre prénom',
          icon: Iconsax.user,
          controller: _firstNameCtl,
          focusNode: _firstNameFocus,
          isFocused: _firstNameFocused,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _AppField(
          label: 'Adresse e-mail',
          hint: 'votre@email.com',
          icon: Iconsax.sms,
          controller: _emailCtl,
          focusNode: _emailFocus,
          isFocused: _emailFocused,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _AppField(
          label: 'Téléphone (optionnel)',
          hint: '+229 XX XX XX',
          icon: Iconsax.call,
          controller: _phoneCtl,
          focusNode: _phoneFocus,
          isFocused: _phoneFocused,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        // ── Date de naissance ──
        _DatePickerField(
          label: 'Date de naissance',
          value: _birthDate,
          onPick: (picked) => setState(() => _birthDate = picked),
        ),
        const SizedBox(height: 16),

        _AppField(
          label: 'Mot de passe',
          hint: '8 caractères minimum',
          icon: Iconsax.lock,
          controller: _passCtl,
          focusNode: _passFocus,
          isFocused: _passFocused,
          isPassword: true,
          obscure: _obscurePass,
          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _AppField(
          label: 'Confirmer le mot de passe',
          hint: 'Répétez votre mot de passe',
          icon: Iconsax.lock_1,
          controller: _confirmCtl,
          focusNode: _confirmFocus,
          isFocused: _confirmFocused,
          isPassword: true,
          obscure: _obscureConfirm,
          onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Password strength indicators
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              ...[
                ['Au moins 8 caractères',    _passCtl.text.length >= 8],
                ['Une majuscule',            _passCtl.text.contains(RegExp(r'[A-Z]'))],
                ['Un chiffre',               _passCtl.text.contains(RegExp(r'[0-9]'))],
                ['Mots de passe identiques', _passCtl.text.isNotEmpty && _passCtl.text == _confirmCtl.text],
              ].map((check) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (check[1] as bool)
                            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: (check[1] as bool)
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: (check[1] as bool)
                          ? const Icon(Icons.check, size: 12, color: Color(0xFF22C55E))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(check[0] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: (check[1] as bool)
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF9CA3AF),
                        fontWeight: (check[1] as bool) ? FontWeight.w500 : FontWeight.w400,
                      )),
                  ],
                ),
              )),
            ],
          ),
        ),
      ].animate(interval: 50.ms).fadeIn(duration: 250.ms).slideY(begin: 0.04),
    );
  }

  // ── ÉTAPE 2 : Académique ─────────────────────────────────────────────────────
  Widget _step2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Bannière université (fixe, non modifiable) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFEFF6FF),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(children: [
            const Icon(Iconsax.building, size: 20, color: _blue),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _universityName.isNotEmpty ? _universityName : 'Chargement…',
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8),
                  ),
                ),
                Text('Votre matricule sera généré automatiquement', style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF3B82F6),
                )),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Filière : dropdown si disponible, sinon champ texte ──
        if (_loadingFilieres)
          Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              color: Colors.white,
            ),
            child: const Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
                SizedBox(width: 10),
                Text('Chargement des filières…',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ]),
            ),
          )
        else if (_filieresFromApi.isNotEmpty)
          _AppDropdown<int>(
            label: 'Filière',
            hint: 'Sélectionnez votre filière',
            icon: Iconsax.book_1,
            value: _selectedFiliereId,
            items: _filieresFromApi.map((f) => DropdownMenuItem(
              value: f['id'] as int,
              child: Text(f['name'] as String, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) {
              final found = _filieresFromApi.firstWhere(
                (f) => f['id'] == v, orElse: () => {});
              setState(() {
                _selectedFiliereId   = v;
                _selectedFiliereName = found['name'] as String?;
              });
            },
          )
        else
          _AppField(
            label: 'Filière',
            hint: 'ex: Informatique, Génie Civil…',
            icon: Iconsax.book_1,
            controller: _filiereCtl,
            focusNode: _filiereFocus,
            isFocused: _filiereFocused,
            textInputAction: TextInputAction.done,
          ),
        const SizedBox(height: 16),

        // ── Niveau ──
        _AppDropdown<String>(
          label: "Niveau d'étude",
          hint: "Sélectionnez votre niveau",
          icon: Iconsax.ranking_1,
          value: _selectedNiveau,
          items: _niveaux.map((n) => DropdownMenuItem(
            value: n,
            child: Text(n),
          )).toList(),
          onChanged: (v) => setState(() => _selectedNiveau = v),
        ),

      ].animate(interval: 50.ms).fadeIn(duration: 260.ms).slideY(begin: 0.04),
    );
  }
}

// ── Labeled App Field ─────────────────────────────────────────────────────────
class _AppField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isFocused;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;

  const _AppField({
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.focusNode,
    this.isFocused = false,
    this.isPassword = false,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  static const _blue      = Color(0xFF2563EB);
  static const _gray      = Color(0xFFE5E7EB);
  static const _labelColor    = Color(0xFF374151);
  static const _labelFocused  = Color(0xFF2563EB);
  static const _iconIdle      = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFocused ? _labelFocused : _labelColor,
          ),
          child: Text(label),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(
              color: isFocused ? _blue : _gray,
              width: isFocused ? 1.5 : 1.0,
            ),
            boxShadow: isFocused
                ? [BoxShadow(color: _blue.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 2))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: isPassword && obscure,
            onChanged: onChanged,
            style: GoogleFonts.inter(
              color: const Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 15),
              prefixIcon: Icon(icon, size: 20,
                  color: isFocused ? _blue : _iconIdle),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure ? Iconsax.eye_slash : Iconsax.eye,
                        size: 20,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Labeled App Dropdown ──────────────────────────────────────────────────────
class _AppDropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _AppDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  static const _blue  = Color(0xFF2563EB);
  static const _gray  = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final selected = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _blue : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(
              color: selected ? _blue : _gray,
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: selected
                ? [BoxShadow(color: _blue.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 2))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
                  const SizedBox(width: 12),
                  Text(hint,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF9CA3AF),
                    )),
                ],
              ),
              icon: Icon(
                Iconsax.arrow_down,
                size: 18,
                color: selected ? _blue : const Color(0xFF9CA3AF),
              ),
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Date Picker Field ─────────────────────────────────────────────────────────
class _DatePickerField extends StatefulWidget {
  final String    label;
  final DateTime? value;
  final void Function(DateTime) onPick;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  State<_DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<_DatePickerField> {
  static const _blue         = Color(0xFF2563EB);
  static const _gray         = Color(0xFFE5E7EB);
  static const _labelColor   = Color(0xFF374151);
  static const _labelFocused = Color(0xFF2563EB);
  static const _iconIdle     = Color(0xFF9CA3AF);

  bool _focused = false;

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  Future<void> _pick() async {
    setState(() => _focused = true);
    final now     = DateTime.now();
    final initial = widget.value ?? DateTime(now.year - 20);
    final picked  = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate:  DateTime(now.year - 10),
      locale:    const Locale('fr'),
      helpText:    'Date de naissance',
      cancelText:  'Annuler',
      confirmText: 'Confirmer',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   _blue,
            onPrimary: Colors.white,
            surface:   Colors.white,
            onSurface: Color(0xFF111827),
          ),
          dialogTheme: const DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() => _focused = false);
    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    final active   = _focused || hasValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? _labelFocused : _labelColor,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(
                color: active ? _blue : _gray,
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [BoxShadow(color: _blue.withValues(alpha: 0.10),
                      blurRadius: 8, offset: const Offset(0, 2))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3, offset: const Offset(0, 1))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_1,
                  size: 20,
                  color: active ? _blue : _iconIdle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? _format(widget.value!) : 'JJ / MM / AAAA',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down,
                  size: 18,
                  color: active ? _blue : _iconIdle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error pill ────────────────────────────────────────────────────────────────
class _ErrorPill extends StatelessWidget {
  final String message;
  const _ErrorPill({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFFEF4444),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
