import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bgDeep, AppTheme.bg, AppTheme.bgAlt],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, state),
              Expanded(
                child: state.isLoading && state.notifications.isEmpty
                    ? _buildSkeleton()
                    : state.notifications.isEmpty
                        ? _buildEmpty()
                        : _buildList(state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, NotificationState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Iconsax.arrow_left,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications',
                    style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    )),
                if (state.unreadCount > 0)
                  Text('${state.unreadCount} non lue(s)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.cyan,
                        fontWeight: FontWeight.w500,
                      )),
              ],
            ),
          ),
          if (state.unreadCount > 0)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref
                    .read(notificationProvider.notifier)
                    .markAllAsRead();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyan.withValues(alpha: 0.2),
                      AppTheme.violet.withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(
                      color: AppTheme.cyan.withValues(alpha: 0.3)),
                ),
                child: Text('Tout lire',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cyan,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  // ── Liste ───────────────────────────────────────────────────────────────────
  Widget _buildList(NotificationState state) {
    return RefreshIndicator(
      color: AppTheme.cyan,
      backgroundColor: AppTheme.bgCard,
      onRefresh: () =>
          ref.read(notificationProvider.notifier).fetchNotifications(),
      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.notifications.length,
        itemBuilder: (context, i) {
          final notif = state.notifications[i];
          return _NotifTile(
            key: ValueKey(notif.id),
            notif: notif,
            onTap: () {
              HapticFeedback.selectionClick();
              if (!notif.isRead) {
                ref
                    .read(notificationProvider.notifier)
                    .markAsRead(notif.id);
              }
            },
            onDelete: () {
              HapticFeedback.mediumImpact();
              ref
                  .read(notificationProvider.notifier)
                  .deleteNotification(notif.id);
            },
          );
        },
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.cyan.withValues(alpha: 0.15),
                  AppTheme.violet.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Icon(Iconsax.notification,
                color: Colors.white38, size: 38),
          ),
          const SizedBox(height: 20),
          Text('Aucune notification',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
          const SizedBox(height: 8),
          Text(
            'Tu seras notifié des nouvelles\nséances et modifications.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white38,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Skeleton loading ────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

// ─── Tuile notification ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifTile({
    super.key,
    required this.notif,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isScheduleCreated = notif.notifType == 'schedule_created';
    final accentColor =
        isScheduleCreated ? AppTheme.cyan : AppTheme.cyanDark;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.danger.withValues(alpha: 0.15),
        ),
        child: const Icon(Iconsax.trash, color: Color(0xFFEF4444), size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: notif.isRead
                ? Colors.white.withValues(alpha: 0.04)
                : accentColor.withValues(alpha: 0.08),
            border: Border.all(
              color: notif.isRead
                  ? Colors.white.withValues(alpha: 0.07)
                  : accentColor.withValues(alpha: 0.25),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icone type
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withValues(alpha: 0.3),
                            accentColor.withValues(alpha: 0.15),
                          ],
                        ),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        isScheduleCreated
                            ? Iconsax.calendar_add
                            : Iconsax.edit,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 13),
                    // Contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(notif.title,
                                    style: GoogleFonts.sora(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    )),
                              ),
                              if (!notif.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor
                                            .withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(notif.body,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: Colors.white60,
                                height: 1.4,
                              )),
                          const SizedBox(height: 8),
                          // Méta infos
                          if (notif.payload != null)
                            _buildPayloadChips(notif.payload!, accentColor),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(notif.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayloadChips(
      Map<String, dynamic> payload, Color accentColor) {
    final chips = <Widget>[];

    if (payload['day'] != null) {
      chips.add(_Chip(
        icon: Iconsax.calendar_1,
        label: _translateDay(payload['day'] as String),
        color: accentColor,
      ));
    }
    if (payload['start_time'] != null && payload['end_time'] != null) {
      chips.add(_Chip(
        icon: Iconsax.clock,
        label:
            '${payload['start_time']} – ${payload['end_time']}',
        color: accentColor,
      ));
    }
    if (payload['room'] != null) {
      chips.add(_Chip(
        icon: Iconsax.building,
        label: payload['room'] as String,
        color: accentColor,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  String _translateDay(String day) {
    const map = {
      'Monday': 'Lundi', 'Tuesday': 'Mardi', 'Wednesday': 'Mercredi',
      'Thursday': 'Jeudi', 'Friday': 'Vendredi', 'Saturday': 'Samedi',
    };
    return map[day] ?? day;
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1)    return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}

// ─── Chip info ─────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ─── Skeleton tile ─────────────────────────────────────────────────────────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
