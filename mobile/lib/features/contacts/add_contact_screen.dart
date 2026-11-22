import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database.dart';
import '../../core/formatters.dart';
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/contact.dart';
import '../../models/enums.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/follow_up_repository.dart';
import '../../services/auth_controller.dart';
import '../../services/sync_service.dart';

final recentNeighborhoodsProvider = FutureProvider<List<String>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepositoryProvider).recentNeighborhoods();
});

/// Saisie rapide terrain : objectif moins d'une minute, utilisable d'une main.
/// Seuls prénom, nom et origine sont obligatoires ; le reste est facultatif.
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

enum _AfterSave { openFile, next }

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _neighborhood = TextEditingController();
  final _arrondissement = TextEditingController();
  final _addressHint = TextEditingController();
  final _notes = TextEditingController();

  var _draft = ContactDraft();
  List<Contact> _duplicates = const [];
  Timer? _debounce;
  bool _saving = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_firstName, _lastName, _phone, _neighborhood, _arrondissement, _addressHint, _notes]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  // ── Doublons : vérification dès la saisie du numéro ──────────

  void _onPhoneChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final found = await ref.read(contactRepositoryProvider).findByPhone(_phone.text);
      if (mounted) setState(() => _duplicates = found);
    });
    setState(() {});
  }

  DateTime get _reminderDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 2, 10);
  }

  // ── Enregistrement ───────────────────────────────────────────

  Future<void> _save(_AfterSave after) async {
    if (!_form.currentState!.validate()) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Numéro déjà connu : on propose, on ne bloque pas.
    final dups = await ref.read(contactRepositoryProvider).findByPhone(_phone.text);
    if (dups.isNotEmpty && mounted) {
      final choice = await _askDuplicate(dups.first);
      if (choice == null || !mounted) return;
      if (choice == _DupChoice.open) {
        context.go('/contacts/${dups.first.uuid}');
        return;
      }
      if (choice == _DupChoice.encounter) {
        await ref
            .read(contactRepositoryProvider)
            .addEncounter(
              dups.first.uuid,
              _draft.source == ContactSource.accueil ? ContactEventType.visiteCulte : ContactEventType.rencontreCampagne,
              user,
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              location: _neighborhood.text.trim().isEmpty ? null : _neighborhood.text.trim(),
            );
        _afterWrite('Nouvelle rencontre ajoutée au dossier de ${dups.first.fullName}.');
        _reset();
        return;
      }
    }

    setState(() => _saving = true);
    try {
      _draft
        ..firstName = _firstName.text
        ..lastName = _lastName.text
        ..phone = _phone.text
        ..neighborhood = _neighborhood.text
        ..arrondissement = _arrondissement.text
        ..addressHint = _addressHint.text
        ..notes = _notes.text
        ..teamId = user.primaryTeam?.id
        ..teamName = user.primaryTeam?.name;

      final contact = await ref.read(contactRepositoryProvider).create(_draft, user);

      // Relance automatique J+2, seulement si la personne accepte d'être recontactée.
      if (_draft.wantsContact) {
        await ref
            .read(followUpRepositoryProvider)
            .create(
              contactUuid: contact.uuid,
              type: _draft.preferredChannel == ContactChannel.appel ? FollowUpActionType.appel : FollowUpActionType.whatsapp,
              user: user,
              description: 'Prendre des nouvelles après la rencontre.',
              scheduledAt: _reminderDate,
            );
      }

      _afterWrite('${contact.fullName} enregistré(e)${_draft.wantsContact ? ' · relance ${formatDate(_reminderDate)}' : ''}.');
      if (!mounted) return;
      if (after == _AfterSave.openFile) {
        _reset();
        context.go('/contacts/${contact.uuid}');
      } else {
        _reset(keepContext: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _afterWrite(String message) {
    ref.read(dataRevisionProvider.notifier).bump();
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// [keepContext] : en enchaînant, on garde l'origine et le quartier (même lieu, même campagne).
  void _reset({bool keepContext = false}) {
    final previous = _draft;
    final neighborhood = _neighborhood.text;
    for (final c in [_firstName, _lastName, _phone, _arrondissement, _addressHint, _notes]) {
      c.clear();
    }
    setState(() {
      _draft = ContactDraft();
      _duplicates = const [];
      if (keepContext) {
        _draft.source = previous.source;
        _neighborhood.text = neighborhood;
      } else {
        _neighborhood.clear();
      }
      _showDetails = false;
    });
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<_DupChoice?> _askDuplicate(Contact existing) => showModalBottomSheet<_DupChoice>(
    context: context,
    showDragHandle: true,
    backgroundColor: HF.card,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ce numéro existe déjà', style: HF.heading(20)),
            const SizedBox(height: 8),
            Text(
              'Il appartient au dossier de ${existing.fullName}. Voulez-vous consulter le dossier existant ou enregistrer une nouvelle rencontre ?',
              style: const TextStyle(color: HF.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, _DupChoice.encounter),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Enregistrer une nouvelle rencontre'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _DupChoice.open),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Consulter le dossier'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DupChoice.createAnyway),
              child: const Text('C’est une autre personne : créer un dossier'),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Interface ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncControllerProvider);

    if (user != null && !user.can('contacts.create')) {
      return const Scaffold(
        appBar: HFTopBar(),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Enregistrement non autorisé',
          message: 'Votre rôle ne permet pas d’enregistrer des contacts.',
        ),
      );
    }

    return Scaffold(
      appBar: const HFTopBar(),
      body: Form(
        key: _form,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _sessionBanner(user?.primaryTeam?.name, sync.online),
            const SizedBox(height: 16),
            _identityCard(),
            const SizedBox(height: 16),
            _originCard(),
            const SizedBox(height: 16),
            _wishesCard(),
            const SizedBox(height: 16),
            _consentCard(),
            const SizedBox(height: 16),
            _notesCard(),
            const SizedBox(height: 16),
            _detailsCard(),
            const SizedBox(height: 16),
            if (_draft.wantsContact) ...[_reminderBanner(), const SizedBox(height: 20)],
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(_AfterSave.openFile),
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.how_to_reg_outlined),
              label: Text(_draft.wantsContact ? 'Enregistrer (+ Relance J+2)' : 'Enregistrer'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: HF.sand, foregroundColor: HF.charcoal),
                onPressed: _saving ? null : () => _save(_AfterSave.next),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Sauvegarder et enchaîner'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionBanner(String? team, bool online) => HFCard(
    color: HF.sand,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: HF.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HF.linen),
          ),
          child: const Icon(Icons.place_outlined, color: HF.terracotta, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAISIE TERRAIN · ${formatDate(DateTime.now()).toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: HF.muted),
              ),
              Text(
                team ?? 'Sans équipe',
                overflow: TextOverflow.ellipsis,
                style: HF.heading(16, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Pill(
          online ? 'En ligne' : 'Hors-ligne prêt',
          bg: online ? HF.sageWash : HF.amberWash,
          fg: online ? HF.sageDark : const Color(0xFFB45309),
          icon: online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        ),
      ],
    ),
  );

  Widget _identityCard() {
    final normalized = normalizePhone(_phone.text);
    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.badge_outlined,
            title: 'Identité & coordonnées',
            trailing: Pill('Terrain 1-main', bg: HF.terracottaWash, fg: HF.terracottaDark),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Prénom *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Téléphone / WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (normalized != null && _duplicates.isEmpty)
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: HF.sage),
                    SizedBox(width: 4),
                    Text(
                      'Format valide',
                      style: TextStyle(fontSize: 12, color: HF.sage, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HF.sand,
                  borderRadius: BorderRadius.circular(HF.radius),
                  border: Border.all(color: HF.inputBorder),
                ),
                child: const Text('🇨🇬 +242', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17, letterSpacing: 0.5),
                  decoration: const InputDecoration(hintText: '06 123 45 67'),
                  validator: (v) => (v != null && v.trim().isNotEmpty && normalizePhone(v) == null) ? 'Numéro incomplet' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Facultatif : une personne peut être enregistrée sans numéro.',
            style: TextStyle(fontSize: 12, color: HF.muted),
          ),
          if (_duplicates.isNotEmpty) ...[const SizedBox(height: 12), _duplicateBanner(_duplicates.first)],
          const SizedBox(height: 18),
          const Text('Quartier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ref
              .watch(recentNeighborhoodsProvider)
              .maybeWhen(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final q in list)
                              QuickChip(
                                label: q,
                                selected: _neighborhood.text.trim().toLowerCase() == q.toLowerCase(),
                                onTap: () => setState(() => _neighborhood.text = q),
                              ),
                          ],
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
          TextFormField(
            controller: _neighborhood,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Autre quartier…', prefixIcon: Icon(Icons.location_on_outlined)),
          ),
        ],
      ),
    );
  }

  Widget _duplicateBanner(Contact c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: HF.amberWash, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Numéro déjà connu : ${c.fullName}${c.neighborhood != null ? ' · ${c.neighborhood}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7A3E06)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => context.go('/contacts/${c.uuid}'), child: const Text('Voir le dossier')),
        ),
      ],
    ),
  );

  Widget _originCard() => HFCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.alt_route,
          title: 'Origine du contact',
          trailing: Pill('1 tap', bg: HF.amberWash, fg: Color(0xFFB45309)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            for (final (src, icon) in [
              (ContactSource.evangelisation, Icons.campaign_outlined),
              (ContactSource.accueil, Icons.church_outlined),
              (ContactSource.invitationMembre, Icons.group_add_outlined),
              (ContactSource.autreActivite, Icons.celebration_outlined),
            ])
              _SelectTile(
                icon: icon,
                label: src.label,
                selected: _draft.source == src,
                onTap: () => setState(() => _draft.source = src),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _wishesCard() {
    Widget tile(String label, IconData icon, bool? value, void Function(bool) set) {
      final selected = value == true;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected ? HF.terracottaDark : HF.sand,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => set(!selected)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: selected ? Colors.white24 : HF.card, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 18, color: selected ? Colors.white : HF.terracotta),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : HF.charcoal,
                      ),
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    color: selected ? Colors.white : HF.inputBorder,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return HFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.checklist,
            title: 'Souhaits exprimés',
            subtitle: 'Seulement si la personne l’a dit',
            trailing: Text(
              'Facultatif',
              style: TextStyle(fontSize: 12, color: HF.muted, fontWeight: FontWeight.w600),
            ),
          ),
          tile(
            'Invitation au culte',
            Icons.event_outlined,
            _draft.wantsServiceInvitation,
            (v) => _draft.wantsServiceInvitation = v,
          ),
          tile(
            'Être accompagné(e) spirituellement',
            Icons.volunteer_activism_outlined,
            _draft.wantsSpiritualSupport,
            (v) => _draft.wantsSpiritualSupport = v,
          ),
          tile(
            'Découvrir une église de maison',
            Icons.cottage_outlined,
            _draft.wantsHouseChurch,
            (v) => _draft.wantsHouseChurch = v,
          ),
        ],
      ),
    );
  }

  Widget _consentCard() => HFCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.verified_user_outlined,
          title: 'Accord pour être recontacté',
          subtitle: 'À demander explicitement à la personne',
        ),
        Container(
          decoration: BoxDecoration(
            color: _draft.wantsContact ? HF.sageWash : HF.redWash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            value: _draft.wantsContact,
            activeColor: HF.sage,
            onChanged: (v) => setState(() => _draft.wantsContact = v),
            title: Text(
              _draft.wantsContact ? 'Oui, accepte d’être recontacté(e)' : 'Ne souhaite pas être recontacté(e)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _draft.wantsContact ? 'Appels, SMS ou WhatsApp de suivi autorisés.' : 'Aucune relance ne sera proposée.',
            ),
          ),
        ),
        if (_draft.wantsContact) ...[
          const SizedBox(height: 14),
          const Text('Moyen préféré', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ch in ContactChannel.values)
                QuickChip(
                  label: ch.label,
                  selected: _draft.preferredChannel == ch,
                  onTap: () => setState(() => _draft.preferredChannel = _draft.preferredChannel == ch ? null : ch),
                ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _notesCard() => HFCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.notes, title: 'Notes de terrain', subtitle: 'Uniquement ce qui aide l’accompagnement'),
        TextFormField(
          controller: _notes,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex. : préfère être appelée le soir, viendra dimanche avec sa sœur…',
            filled: true,
            fillColor: HF.sand,
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 14, color: HF.sage),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Notes confidentielles, visibles par les responsables habilités',
                style: TextStyle(fontSize: 12, color: HF.sage),
              ),
            ),
            Text('${_notes.text.length}/500', style: const TextStyle(fontSize: 12, color: HF.muted)),
          ],
        ),
      ],
    ),
  );

  Widget _detailsCard() => HFCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        ListTile(
          onTap: () => setState(() => _showDetails = !_showDetails),
          leading: const Icon(Icons.tune, color: HF.terracotta),
          title: Text('Plus de détails', style: HF.heading(16, weight: FontWeight.w600)),
          subtitle: const Text('Sexe, âge, arrondissement, date de rencontre'),
          trailing: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
        ),
        if (_showDetails)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sexe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in Gender.values)
                      QuickChip(
                        label: g.label,
                        selected: _draft.gender == g,
                        onTap: () => setState(() => _draft.gender = _draft.gender == g ? null : g),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Tranche d’âge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in AgeRange.values)
                      QuickChip(
                        label: a.label,
                        selected: _draft.ageRange == a,
                        onTap: () => setState(() => _draft.ageRange = _draft.ageRange == a ? null : a),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _arrondissement,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Arrondissement'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressHint,
                  decoration: const InputDecoration(
                    labelText: 'Indication complémentaire',
                    hintText: 'Ex. : près de la pharmacie',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _draft.firstMetAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _draft.firstMetAt = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Rencontré(e) le ${formatDate(_draft.firstMetAt)}'),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _reminderBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: HF.sageWash, borderRadius: BorderRadius.circular(HF.cardRadius)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: HF.card, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.alarm, color: HF.sage, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relance automatique J+2',
                style: HF.heading(15, weight: FontWeight.w700, color: HF.sageDark),
              ),
              const SizedBox(height: 2),
              Text(
                'Un rappel ${_draft.preferredChannel == ContactChannel.appel ? 'd’appel' : 'WhatsApp'} sera programmé le ${formatDate(_reminderDate)} à 10h00.',
                style: const TextStyle(fontSize: 13, color: HF.sageDark),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum _DupChoice { open, encounter, createAnyway }

class _SelectTile extends StatelessWidget {
  const _SelectTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HF.sageWash : HF.sand,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? HF.sage : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: selected ? HF.sageDark : HF.charcoal, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: selected ? HF.sageDark : HF.charcoal),
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: HF.sage, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
