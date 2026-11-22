import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/contact.dart';
import '../../models/enums.dart';
import '../../models/follow_up.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/follow_up_repository.dart';
import '../../services/auth_controller.dart';
import '../../services/sync_service.dart';

void _afterWrite(BuildContext context, WidgetRef ref, String message) {
  ref.read(dataRevisionProvider.notifier).bump();
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: HF.card,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: child),
  ),
);

// ── Ajouter une action / programmer un suivi ───────────────────

Future<void> showFollowUpSheet(
  BuildContext context,
  WidgetRef ref,
  Contact contact, {
  FollowUpActionType? initialType,
  bool schedule = false,
}) async {
  final saved = await _sheet<String>(context, _FollowUpForm(contact: contact, initialType: initialType, schedule: schedule));
  if (saved != null && context.mounted) _afterWrite(context, ref, saved);
}

class _FollowUpForm extends ConsumerStatefulWidget {
  const _FollowUpForm({required this.contact, this.initialType, this.schedule = false});

  final Contact contact;
  final FollowUpActionType? initialType;
  final bool schedule;

  @override
  ConsumerState<_FollowUpForm> createState() => _FollowUpFormState();
}

class _FollowUpFormState extends ConsumerState<_FollowUpForm> {
  late FollowUpActionType _type = widget.initialType ?? FollowUpActionType.appel;
  late bool _schedule = widget.schedule;
  FollowUpResult? _result;
  late DateTime _when = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1, 10);
  final _description = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _allowed => !_type.requiresConsent || widget.contact.canBeContacted;

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() => _when = DateTime(d.year, d.month, d.day, t?.hour ?? 10, t?.minute ?? 0));
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !_allowed) return;
    if (_type == FollowUpActionType.note && _description.text.trim().isEmpty) return;

    setState(() => _saving = true);
    final isNote = _type == FollowUpActionType.note;
    await ref
        .read(followUpRepositoryProvider)
        .create(
          contactUuid: widget.contact.uuid,
          type: _type,
          user: user,
          description: _description.text,
          result: _schedule || isNote ? null : _result,
          scheduledAt: _schedule && !isNote ? _when : null,
          completedAt: _schedule && !isNote ? null : DateTime.now(),
        );

    // Refus exprimé pendant l'échange : on arrête les relances, comme l'exige le cahier des charges.
    if (!_schedule && _result == FollowUpResult.refusContact) {
      await ref
          .read(contactRepositoryProvider)
          .changeStatus(
            widget.contact,
            ContactStatus.nePlusContacter,
            user,
            reason: 'Refus exprimé lors d’un ${_type.label.toLowerCase()}',
          );
    }

    if (mounted) {
      Navigator.pop(
        context,
        isNote
            ? 'Note ajoutée.'
            : (_schedule ? '${_type.label} programmé le ${formatDateTime(_when)}.' : '${_type.label} enregistré.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNote = _type == FollowUpActionType.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(isNote ? 'Ajouter une note' : 'Suivi de ${widget.contact.firstName}', style: HF.heading(20)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in FollowUpActionType.values)
              QuickChip(
                label: t.label,
                selected: _type == t,
                onTap: () => setState(() {
                  _type = t;
                  _result = null;
                }),
              ),
          ],
        ),
        if (!_allowed) ...[
          const SizedBox(height: 12),
          const Pill(
            'Cette personne ne souhaite plus être contactée : seules les notes sont possibles.',
            bg: HF.redWash,
            fg: HF.red,
            icon: Icons.do_not_disturb_on_outlined,
            maxWidth: double.infinity,
          ),
        ],
        if (!isNote && _allowed) ...[
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.check), label: Text('Fait maintenant')),
              ButtonSegment(value: true, icon: Icon(Icons.event), label: Text('Programmer')),
            ],
            selected: {_schedule},
            onSelectionChanged: (s) => setState(() => _schedule = s.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: HF.sand,
              selectedBackgroundColor: HF.card,
              selectedForegroundColor: HF.terracottaDark,
              side: const BorderSide(color: HF.linen),
            ),
          ),
          const SizedBox(height: 16),
          if (_schedule)
            OutlinedButton.icon(onPressed: _pickWhen, icon: const Icon(Icons.alarm), label: Text(formatDateTime(_when)))
          else ...[
            const Text('Résultat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in FollowUpResult.values)
                  QuickChip(label: r.label, selected: _result == r, onTap: () => setState(() => _result = r)),
              ],
            ),
          ],
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 5,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: isNote ? 'Note *' : 'Commentaire (facultatif)',
            hintText: 'Seulement ce qui aide l’accompagnement',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving || !_allowed ? null : _save,
          child: Text(_schedule && !isNote ? 'Programmer' : 'Enregistrer'),
        ),
      ],
    );
  }
}

// ── Clôturer une relance programmée ───────────────────────────

Future<void> showCompleteSheet(BuildContext context, WidgetRef ref, FollowUp f) async {
  final saved = await _sheet<String>(context, _CompleteForm(followUp: f));
  if (saved != null && context.mounted) _afterWrite(context, ref, saved);
}

class _CompleteForm extends ConsumerStatefulWidget {
  const _CompleteForm({required this.followUp});

  final FollowUp followUp;

  @override
  ConsumerState<_CompleteForm> createState() => _CompleteFormState();
}

class _CompleteFormState extends ConsumerState<_CompleteForm> {
  FollowUpResult? _result;
  bool _scheduleNext = false;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    final result = _result;
    if (user == null || result == null) return;
    final f = widget.followUp;

    await ref.read(followUpRepositoryProvider).complete(f, result, description: _description.text);

    final contact = await ref.read(contactRepositoryProvider).find(f.contactUuid);
    if (contact != null) {
      if (result == FollowUpResult.refusContact) {
        await ref
            .read(contactRepositoryProvider)
            .changeStatus(contact, ContactStatus.nePlusContacter, user, reason: 'Refus exprimé lors du suivi');
      } else if (result == FollowUpResult.joint &&
          (contact.status == ContactStatus.nouveau || contact.status == ContactStatus.aContacter)) {
        await ref
            .read(contactRepositoryProvider)
            .changeStatus(contact, ContactStatus.contacte, user, reason: 'Premier échange effectué');
      }
      if (_scheduleNext && result != FollowUpResult.refusContact) {
        final now = DateTime.now();
        await ref
            .read(followUpRepositoryProvider)
            .create(
              contactUuid: contact.uuid,
              type: f.actionType,
              user: user,
              description: 'Relance',
              scheduledAt: DateTime(now.year, now.month, now.day + 2, 10),
            );
      }
    }
    if (mounted) Navigator.pop(context, 'Suivi enregistré : ${result.label}.');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.followUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${f.actionType.label} · ${f.contactName ?? ''}', style: HF.heading(20)),
        if (f.description != null) ...[const SizedBox(height: 6), Text(f.description!, style: const TextStyle(color: HF.muted))],
        const SizedBox(height: 16),
        const Text('Comment ça s’est passé ?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in FollowUpResult.values)
              QuickChip(label: r.label, selected: _result == r, onTap: () => setState(() => _result = r)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Commentaire (facultatif)'),
        ),
        CheckboxListTile(
          value: _scheduleNext,
          onChanged: (v) => setState(() => _scheduleNext = v ?? false),
          contentPadding: EdgeInsets.zero,
          activeColor: HF.sage,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Programmer une relance dans 2 jours'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _result == null ? null : _save, child: const Text('Valider')),
      ],
    );
  }
}

// ── Changer le statut ─────────────────────────────────────────

Future<void> showStatusSheet(BuildContext context, WidgetRef ref, Contact contact) async {
  final saved = await _sheet<String>(context, _StatusForm(contact: contact));
  if (saved != null && context.mounted) _afterWrite(context, ref, saved);
}

class _StatusForm extends ConsumerStatefulWidget {
  const _StatusForm({required this.contact});

  final Contact contact;

  @override
  ConsumerState<_StatusForm> createState() => _StatusFormState();
}

class _StatusFormState extends ConsumerState<_StatusForm> {
  late ContactStatus _selected = widget.contact.status;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _selected == widget.contact.status) return;
    await ref
        .read(contactRepositoryProvider)
        .changeStatus(widget.contact, _selected, user, reason: _reason.text.trim().isEmpty ? null : _reason.text.trim());
    if (mounted) Navigator.pop(context, 'Statut : ${_selected.label}.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Où en est ${widget.contact.firstName} ?', style: HF.heading(20)),
        const SizedBox(height: 4),
        const Text('Chaque changement est daté et attribué.', style: TextStyle(color: HF.muted)),
        const SizedBox(height: 12),
        for (final s in ContactStatus.values.where((s) => s.manuallyAssignable))
          RadioListTile<ContactStatus>(
            value: s,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v!),
            activeColor: HF.terracotta,
            contentPadding: EdgeInsets.zero,
            title: Align(alignment: Alignment.centerLeft, child: StatusPill(s)),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '« Intégré » se pose automatiquement quand un responsable confirme l’affectation à une église de maison.',
            style: TextStyle(fontSize: 12, color: HF.muted),
          ),
        ),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _selected == widget.contact.status ? null : _save, child: const Text('Mettre à jour')),
      ],
    );
  }
}
