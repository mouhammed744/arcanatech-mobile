import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

/// Type de notification — détermine l'icône et la couleur d'accent
enum BannerType { schedule, added, deleted, modified, general }

/// ─────────────────────────────────────────────────────────────────────────────
/// BannerService — singleton qui affiche le banner WhatsApp-style
///
/// Usage :
///   BannerService.instance.show(
///     title: 'Cours déplacé',
///     body:  'Algorithmique déplacé au jeudi 10h30',
///     type:  BannerType.schedule,
///     onTap: () => router.push('/notifications'),
///   );
/// ─────────────────────────────────────────────────────────────────────────────
class BannerService {
  BannerService._();
  static final BannerService instance = BannerService._();

  /// Clé du navigator racine — à assigner dans app.dart
  GlobalKey<NavigatorState>? navigatorKey;

  OverlayEntry? _currentEntry;
  bool _isShowing = false;

  /// Affiche le banner. Si un banner est déjà visible, il est remplacé.
  void show({
    required String title,
    required String body,
    BannerType type = BannerType.general,
    VoidCallback? onTap,
  }) {
    final overlay =
        navigatorKey?.currentState?.overlay ?? _findOverlay();
    if (overlay == null) return;

    // Fermer le banner courant immédiatement si présent
    _dismiss(animated: false);

    _isShowing = true;
    _currentEntry = OverlayEntry(
      builder: (_) => _NotificationBannerWidget(
        title: title,
        body: body,
        type: type,
        onTap: () {
          _dismiss();
          onTap?.call();
        },
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
    HapticFeedback.lightImpact();
  }

  void _dismiss({bool animated = true}) {
    _currentEntry?.remove();
    _currentEntry = null;
    _isShowing = false;
  }

  OverlayState? _findOverlay() {
    // Fallback: cherche l'overlay dans le contexte global
    return null;
  }

  bool get isShowing => _isShowing;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget interne du banner
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final BannerType type;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with TickerProviderStateMixin {

  // Slide animation (haut → position)
  late AnimationController _slideCtl;
  late Animation<Offset> _slideAnim;

  // Progress bar qui se vide sur 4 secondes
  late AnimationController _progressCtl;

  // Swipe vertical
  double _dragOffset = 0;

  static const Duration _displayDuration = Duration(seconds: 4);
  static const Duration _animDuration    = Duration(milliseconds: 380);

  @override
  void initState() {
    super.initState();

    // Slide in depuis le haut
    _slideCtl = AnimationController(vsync: this, duration: _animDuration);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtl, curve: Curves.easeOutBack));

    // Progress bar
    _progressCtl = AnimationController(
      vsync: this,
      duration: _displayDuration,
    );

    // Lancer les animations
    _slideCtl.forward();
    _progressCtl.forward().then((_) => _dismissAnimated());
  }

  @override
  void dispose() {
    _slideCtl.dispose();
    _progressCtl.dispose();
    super.dispose();
  }

  Future<void> _dismissAnimated() async {
    if (!mounted) return;
    await _slideCtl.reverse();
    if (mounted) widget.onDismiss();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy < 0) {
      setState(() => _dragOffset += d.delta.dy);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragOffset < -40) {
      _progressCtl.stop();
      _dismissAnimated();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  // ── Couleurs par type ──────────────────────────────────────
  Color get _accentColor => Colors.white;

  String get _icon {
    switch (widget.type) {
      case BannerType.schedule:  return '📅';
      case BannerType.added:     return '➕';
      case BannerType.deleted:   return '🗑️';
      case BannerType.modified:  return '✏️';
      case BannerType.general:   return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPad + 8 + _dragOffset.clamp(-200.0, 0.0),
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: widget.onTap,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: SlideTransition(
          position: _slideAnim,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xEA10102A), // bgCard 92% opaque
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Contenu principal ──────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icône
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                color: _accentColor.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: _accentColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Texte
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // App name pill (comme WhatsApp)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: _accentColor.withValues(alpha: 0.15),
                                        ),
                                        child: Text(
                                          'ARCANA TECH',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _accentColor,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _timeAgo(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // Titre
                                  Text(
                                    widget.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),

                                  // Corps
                                  Text(
                                    widget.body,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppTheme.textSecondary,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Bouton fermer
                            GestureDetector(
                              onTap: () {
                                _progressCtl.stop();
                                _dismissAnimated();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Barre de progression ───────────────────
                      AnimatedBuilder(
                        animation: _progressCtl,
                        builder: (_, __) => Container(
                          height: 3,
                          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 1 - _progressCtl.value,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    );
  }

  String _timeAgo() => 'à l\'instant';
}
