import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/notification_provider.dart';

// ─── Constantes de mise en page ───────────────────────────────────────────────
const double _kNavHeight       = 68.0;
const double _kNavBottomPad    = 16.0;
const double _kNavTotalHeight  = _kNavHeight + _kNavBottomPad;
const double _kFabSize         = 62.0;
const double _kFabRadius       = _kFabSize / 2;

/// Clearance pour le contenu des écrans (nav + FAB qui déborde)
const double kBottomNavClearance = _kNavTotalHeight + _kFabRadius + 8;

// ─── Onglets ──────────────────────────────────────────────────────────────────
const _tabs = [
  _TabDef(Iconsax.home_2,    'Accueil',  0),
  _TabDef(Iconsax.calendar_2,'Planning', 1),
  _TabDef(Iconsax.user,      'Profil',   2),
];

// ─── AppShell ─────────────────────────────────────────────────────────────────

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bgDeep, AppTheme.bg, AppTheme.bgAlt],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: navigationShell,
          bottomNavigationBar: _NavWithFAB(
            currentIndex: navigationShell.currentIndex,
            onTap: (idx) {
              HapticFeedback.selectionClick();
              navigationShell.goBranch(
                idx,
                initialLocation: idx == navigationShell.currentIndex,
              );
            },
            onScanTap: () => context.push('/scanner'),
          ),
        ),
      ),
    );
  }
}

// ─── Nav + FAB composite ──────────────────────────────────────────────────────

class _NavWithFAB extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final VoidCallback onScanTap;

  const _NavWithFAB({
    required this.currentIndex,
    required this.onTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    const totalH = _kNavTotalHeight + _kFabRadius;

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _GlassNavBar(
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ),
          Positioned(
            bottom: _kNavTotalHeight - _kFabRadius,
            child: _ScannerFAB(onTap: onScanTap),
          ),
        ],
      ),
    );
  }
}

// ─── Glass Nav Bar ────────────────────────────────────────────────────────────

class _GlassNavBar extends ConsumerWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    const activeColor = AppTheme.cyan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, _kNavBottomPad),
      child: Container(
        height: _kNavHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
              children: [
                // Onglets gauche (0 et 1)
                for (final tab in _tabs.take(2))
                  Expanded(
                    child: _NavTab(
                      tab: tab,
                      active: currentIndex == tab.branchIdx,
                      activeColor: activeColor,
                      onTap: () => onTap(tab.branchIdx),
                      badgeCount: tab.branchIdx == 0 ? unreadCount : 0,
                    ),
                  ),

                // Espace central pour le FAB
                const SizedBox(width: 76),

                // Onglets droite (2 et 3)
                for (final tab in _tabs.skip(2))
                  Expanded(
                    child: _NavTab(
                      tab: tab,
                      active: currentIndex == tab.branchIdx,
                      activeColor: activeColor,
                      onTap: () => onTap(tab.branchIdx),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

// ─── Onglet ───────────────────────────────────────────────────────────────────

class _TabDef {
  final IconData icon;
  final String   label;
  final int      branchIdx;
  const _TabDef(this.icon, this.label, this.branchIdx);
}

class _NavTab extends StatelessWidget {
  final _TabDef  tab;
  final bool     active;
  final Color    activeColor;
  final VoidCallback onTap;
  final int      badgeCount;

  const _NavTab({
    required this.tab,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: active
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: -2,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  tab.icon,
                  size: 22,
                  color: active ? activeColor : AppTheme.textTertiary,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: AppTheme.danger,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.danger.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? activeColor : AppTheme.textTertiary,
            ),
            child: Text(tab.label),
          ),
        ],
      ),
    );
  }
}

// ─── FAB Scanner ──────────────────────────────────────────────────────────────

class _ScannerFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _ScannerFAB({required this.onTap});

  @override
  State<_ScannerFAB> createState() => _ScannerFABState();
}

class _ScannerFABState extends State<_ScannerFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtl;

  @override
  void initState() {
    super.initState();
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtl,
      builder: (context, _) {
        final pulse = _pulseCtl.value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onTap();
          },
          child: Container(
            width: _kFabSize,
            height: _kFabSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB)
                      .withValues(alpha: 0.35 + pulse * 0.25),
                  blurRadius: 18 + pulse * 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  blurRadius: 45,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Iconsax.scan,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}
