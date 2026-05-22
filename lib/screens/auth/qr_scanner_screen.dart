import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _blue     = Color(0xFF2563EB);
const _blueDark = Color(0xFF1D4ED8);

class QrScannerScreen extends StatefulWidget {
  /// Appelé quand un QR valide est détecté.
  /// Retourne une Map des données extraites (peut être vide si format inconnu).
  final void Function(Map<String, String> data) onResult;

  const QrScannerScreen({super.key, required this.onResult});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _scanned  = false;
  bool _torch    = false;
  late AnimationController _lineCtl;

  @override
  void initState() {
    super.initState();
    _lineCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _lineCtl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _scanned = true;
    HapticFeedback.mediumImpact();
    _controller.stop();

    // ── Tente de parser le QR ────────────────────────────────────────────
    // Format attendu : champ=valeur;champ=valeur;...
    // ex: nom=ADJAVON;prenom=Koffi;matricule=2024-UAC-001;email=k@uac.bj
    final parsed = _parseQr(raw);

    widget.onResult(parsed);
    Navigator.of(context).pop();
  }

  Map<String, String> _parseQr(String raw) {
    final result = <String, String>{};
    // Format clé=valeur séparé par ; ou |
    final pairs = raw.split(RegExp(r'[;|]'));
    for (final pair in pairs) {
      final idx = pair.indexOf('=');
      if (idx > 0) {
        final key = pair.substring(0, idx).trim().toLowerCase();
        final val = pair.substring(idx + 1).trim();
        result[key] = val;
      }
    }
    // Si aucun format structuré, on met le contenu brut dans matricule
    if (result.isEmpty) {
      result['matricule'] = raw.trim();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width * 0.68;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Caméra ──────────────────────────────────────────────────
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

            // ── Overlay sombre + découpe centrale ────────────────────────
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.transparent,
                BlendMode.dstOut,
              ),
              child: Stack(
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.62)),
                  Center(
                    child: Container(
                      width: frameSize,
                      height: frameSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Coins du cadre QR (bleu vif) ─────────────────────────────
            Center(
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: CustomPaint(
                  painter: _CornerPainter(color: _blue),
                ),
              ),
            ),

            // ── Ligne de scan animée ──────────────────────────────────────
            Center(
              child: SizedBox(
                width: frameSize - 8,
                height: frameSize - 8,
                child: AnimatedBuilder(
                  animation: _lineCtl,
                  builder: (_, __) => Stack(
                    children: [
                      Positioned(
                        top: (frameSize - 8) * _lineCtl.value,
                        left: 0, right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _blue.withValues(alpha: 0),
                                _blue,
                                _blue.withValues(alpha: 0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Texte guide ───────────────────────────────────────────────
            Positioned(
              bottom: size.height * 0.28,
              left: 0, right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Pointez le QR code de votre carte étudiant',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Barre de contrôles (haut) ─────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bouton fermer
                    _ControlBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    // Titre
                    Text(
                      'Scanner QR',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    // Torche
                    _ControlBtn(
                      icon: _torch ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded,
                      onTap: () {
                        setState(() => _torch = !_torch);
                        _controller.toggleTorch();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Bouton "Saisir manuellement" en bas ───────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: GestureDetector(
                    onTap: () {
                      // Retourne une map vide → l'utilisateur saisira manuellement
                      _controller.stop();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [_blue, _blueDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.keyboard, size: 18, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              'Saisir manuellement',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ── Bouton de contrôle circulaire ─────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Coins du cadre QR ────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r   = 16.0;

    // Coin haut-gauche
    canvas.drawPath(Path()
      ..moveTo(0, len + r)
      ..arcToPoint(Offset(r, r), radius: const Radius.circular(r))
      ..lineTo(len + r, r), paint);

    // Coin haut-droit
    canvas.drawPath(Path()
      ..moveTo(size.width - len - r, r)
      ..lineTo(size.width - r, r)
      ..arcToPoint(Offset(size.width, r + r), radius: const Radius.circular(r))
      ..lineTo(size.width, r + len + r), paint);

    // Coin bas-droit
    canvas.drawPath(Path()
      ..moveTo(size.width, size.height - len - r)
      ..arcToPoint(Offset(size.width - r, size.height - r), radius: const Radius.circular(r))
      ..lineTo(size.width - len - r, size.height - r), paint);

    // Coin bas-gauche
    canvas.drawPath(Path()
      ..moveTo(len + r, size.height - r)
      ..lineTo(r, size.height - r)
      ..arcToPoint(Offset(0, size.height - r - r), radius: const Radius.circular(r))
      ..lineTo(0, size.height - r - len - r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
