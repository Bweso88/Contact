import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../services/auth_controller.dart';
import '../services/sync_service.dart';
import 'theme.dart';

/// Carte blanche à bordure fine (niveau 1 de la maquette).
class HFCard extends StatelessWidget {
  const HFCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? HF.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HF.cardRadius),
        side: BorderSide(color: borderColor ?? HF.linen),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// En-tête de section : icône terracotta + titre + élément à droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title, this.subtitle, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 22, color: HF.terracotta),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HF.heading(17, weight: FontWeight.w600)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 13, color: HF.muted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Petite pastille arrondie (« Terrain 1-main », « Étape 2 / 6 »…).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.bg = HF.sand, this.fg = HF.charcoal, this.icon, this.dot = false, this.maxWidth = 240});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool dot;

  /// Borne la largeur : la pastille reste utilisable dans une Row non contrainte.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final ContactStatus status;

  @override
  Widget build(BuildContext context) {
    final c = statusColors(status);
    return Pill(status.label, bg: c.bg, fg: c.fg, dot: true, maxWidth: 170);
  }
}

/// Initiales à la place d'une photo (minimisation des données).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 48, this.badge});

  final String initials;
  final double size;
  final Widget? badge;

  static const _palette = [
    (HF.terracottaWash, Color(0xFF9C3D20)),
    (HF.sageWash, Color(0xFF234E3F)),
    (HF.amberWash, Color(0xFFB45309)),
  ];

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette[initials.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
            child: Text(initials, style: HF.heading(size * 0.36, color: fg)),
          ),
          if (badge != null) Positioned(right: -4, bottom: -4, child: badge!),
        ],
      ),
    );
  }
}

/// Bouton d'action de la maquette (WhatsApp sauge, Appeler sable…).
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.bg = HF.sand,
    this.fg = HF.charcoal,
    this.vertical = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final content = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 20),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
              ],
            ],
          );

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: vertical ? 72 : 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre du haut commune : nom de l'église, état réseau, avatar (→ profil).
class HFTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const HFTopBar({super.key, this.title});

  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncControllerProvider);
    final initials = (user?.name ?? '?').split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: HF.terracotta, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_florist_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title ?? 'Église Connect', overflow: TextOverflow.ellipsis, style: HF.heading(17)),
                _NetworkLine(sync: sync),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkResponse(
            onTap: () => context.push('/profil'),
            radius: 28,
            child: Badge(
              isLabelVisible: sync.pending > 0 || sync.conflicts > 0,
              backgroundColor: sync.conflicts > 0 ? HF.red : HF.amber,
              label: Text('${sync.conflicts > 0 ? sync.conflicts : sync.pending}'),
              child: InitialsAvatar(initials, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkLine extends StatelessWidget {
  const _NetworkLine({required this.sync});

  final SyncStatus sync;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color color) = sync.running
        ? (Icons.sync, 'Synchronisation…', HF.sage)
        : sync.online
        ? (Icons.cloud_done_outlined, sync.pending > 0 ? 'En ligne · ${sync.pending} en attente' : 'En ligne', HF.sage)
        : (Icons.cloud_off_outlined, sync.pending > 0 ? 'Hors ligne · ${sync.pending} en attente' : 'Hors ligne prêt', HF.amber);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// Puce sélectionnable 1-tap (« Quick-Tap Chips »).
class QuickChip extends StatelessWidget {
  const QuickChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HF.terracottaDark : HF.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? HF.terracottaDark : HF.linen)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                if (!selected && icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 16, color: HF.charcoal),
                  ),
                Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : HF.charcoal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Message vide centré.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: HF.linen),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HF.heading(16, weight: FontWeight.w600),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HF.muted),
            ),
          ],
        ],
      ),
    );
  }
}
