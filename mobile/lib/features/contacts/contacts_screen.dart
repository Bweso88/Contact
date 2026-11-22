import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database.dart';
import '../../core/formatters.dart';
import '../../core/launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/enums.dart';
import '../../repositories/contact_repository.dart';
import '../shell/home_shell.dart';
import '../suivi/follow_up_sheets.dart';

typedef ContactQuery = ({String search, ContactListFilter filter});

final contactListProvider = FutureProvider.family<List<ContactListItem>, ContactQuery>((ref, q) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).list(search: q.search, filter: q.filter);
});

final contactFilterCountsProvider = FutureProvider<Map<ContactListFilter, int>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).filterCounts();
});

/// Répertoire des contacts (écran « r_pertoire_suivi » de la maquette).
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _search = TextEditingController();
  String _query = '';
  ContactListFilter _filter = ContactListFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(contactListProvider((search: _query, filter: _filter)));
    final counts = ref.watch(contactFilterCountsProvider).valueOrNull ?? const {};
    final due = ref.watch(dueCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: const HFTopBar(),
      floatingActionButton: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: HF.primaryGlow),
        child: FloatingActionButton(
          tooltip: 'Nouveau contact',
          backgroundColor: HF.terracotta,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => context.go('/nouveau'),
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      body: RefreshIndicator(
        color: HF.terracotta,
        onRefresh: () async => ref.read(dataRevisionProvider.notifier).bump(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList.list(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un nom, un quartier, un numéro…',
                      prefixIcon: const Icon(Icons.search),
                      fillColor: HF.sand,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in ContactListFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: f.label,
                              count: counts[f],
                              selected: _filter == f,
                              urgent: f == ContactListFilter.toContact,
                              onTap: () => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (due > 0) ...[const SizedBox(height: 14), _PriorityBanner(count: due)],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        _filter == ContactListFilter.all ? 'Contacts récents' : _filter.label,
                        style: HF.heading(17, weight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Text(
                        'Par activité',
                        style: TextStyle(fontSize: 13, color: HF.terracottaDark, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            list.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: HF.terracotta)),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: EmptyState(icon: Icons.error_outline, title: 'Erreur de lecture', message: '$e'),
              ),
              data: (items) => items.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.person_search_outlined,
                        title: _query.isEmpty ? 'Aucun contact ici' : 'Aucun résultat pour « $_query »',
                        message: _query.isEmpty ? 'Touchez + pour enregistrer une première personne.' : null,
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => ContactCard(item: items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap, this.urgent = false});

  final String label;
  final int? count;
  final bool selected;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? HF.terracottaDark : (urgent ? HF.amberWash : HF.card);
    final fg = selected ? Colors.white : (urgent ? const Color(0xFF7A3E06) : HF.charcoal);
    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: selected || urgent ? Colors.transparent : HF.linen)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (urgent && !selected) ...[
                const Icon(Icons.priority_high, size: 16, color: Color(0xFFB45309)),
                const SizedBox(width: 2),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white24 : (urgent ? const Color(0xFFB45309) : HF.sand),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected || urgent ? Colors.white : HF.charcoal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBanner extends StatelessWidget {
  const _PriorityBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HF.sageWash,
      borderRadius: BorderRadius.circular(HF.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(HF.cardRadius),
        onTap: () => context.go('/suivi'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: HF.sageDark,
                child: Icon(Icons.notifications_active_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Relances prioritaires', style: HF.heading(16, color: HF.sageDark)),
                        ),
                        const Pill('Aujourd’hui', bg: HF.card, fg: HF.sageDark),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1
                          ? '1 personne attend votre message pour garder le lien.'
                          : '$count personnes attendent votre message pour garder le lien.',
                      style: const TextStyle(color: HF.sageDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte contact du répertoire (« Contact Cards » de la maquette).
class ContactCard extends ConsumerWidget {
  const ContactCard({super.key, required this.item});

  final ContactListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = item.contact;
    final phone = c.phone;
    final canReach = c.canBeContacted && phone != null;
    final isNew = c.status == ContactStatus.nouveau || c.status == ContactStatus.aContacter;

    return HFCard(
      onTap: () => context.go('/contacts/${c.uuid}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(c.initials, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HF.heading(18, weight: FontWeight.w600),
                          ),
                        ),
                        if (isNew && c.lastFollowUpAt == null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: HF.red, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: HF.muted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            [c.neighborhood, c.source.label].whereType<String>().join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: HF.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(c.status),
            ],
          ),
          if (item.lastNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HF.sand, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 15, color: HF.terracottaDark),
                      SizedBox(width: 6),
                      Text(
                        'Dernière note',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HF.terracottaDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '« ${item.lastNote} »',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          if (item.nextFollowUpAt != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: HF.amberWash, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  const Text('Relance : ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    formatRelative(item.nextFollowUpAt!),
                    style: const TextStyle(fontSize: 13, color: HF.terracottaDark, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: HF.muted),
              const SizedBox(width: 4),
              Text(formatRelative(c.updatedAt), style: const TextStyle(fontSize: 12, color: HF.muted)),
              const Spacer(),
              if (c.syncState != SyncState.synced) ...[
                Icon(
                  c.syncState == SyncState.conflict ? Icons.sync_problem : Icons.cloud_upload_outlined,
                  size: 14,
                  color: c.syncState == SyncState.conflict ? HF.red : HF.amber,
                ),
                const SizedBox(width: 8),
              ],
              if (c.assignedUserName != null) ...[
                const Icon(Icons.person_outline, size: 14, color: HF.muted),
                const SizedBox(width: 2),
                Text(c.assignedUserName!, style: const TextStyle(fontSize: 12, color: HF.muted)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (!c.canBeContacted)
            const Pill('Ne souhaite plus être contacté', bg: HF.redWash, fg: HF.red, icon: Icons.do_not_disturb_on_outlined)
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ActionTile(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    bg: HF.sageWash,
                    fg: HF.sageDark,
                    onTap: canReach ? () => Launcher.whatsapp(context, phone) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(
                    icon: Icons.call_outlined,
                    label: '',
                    onTap: canReach ? () => Launcher.call(context, phone) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ActionTile(
                    icon: Icons.edit_note,
                    label: 'Note',
                    fg: HF.terracottaDark,
                    onTap: () => showFollowUpSheet(context, ref, c, initialType: FollowUpActionType.note),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
