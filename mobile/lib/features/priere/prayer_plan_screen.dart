import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/prayer.dart';
import '../../repositories/prayer_repository.dart';

final _intercessorsProvider = FutureProvider.autoDispose<List<PrayerPerson>>(
  (ref) => ref.watch(prayerRepositoryProvider).intercessors(),
);

/// Planification d'une chaîne (responsable prière) : créneaux consécutifs attribués aux intercesseurs.
class PrayerPlanScreen extends ConsumerStatefulWidget {
  const PrayerPlanScreen({super.key});

  @override
  ConsumerState<PrayerPlanScreen> createState() => _PrayerPlanScreenState();
}

class _PrayerPlanScreenState extends ConsumerState<PrayerPlanScreen> {
  final _title = TextEditingController(text: 'Chaîne de prière');
  final _description = TextEditingController();
  final _whatsapp = TextEditingController();
  late DateTime _start = _defaultStart();
  int _slotMinutes = 60;
  final List<int?> _assignees = [null, null, null];
  bool _saving = false;

  static DateTime _defaultStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour + 1);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  DateTime _slotStart(int i) => _start.add(Duration(minutes: _slotMinutes * i));

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack('Donnez un titre à la chaîne.');
      return;
    }
    if (_assignees.any((a) => a == null)) {
      _snack('Attribuez chaque créneau à un intercesseur.');
      return;
    }

    setState(() => _saving = true);
    try {
      final uuid = await ref
          .read(prayerRepositoryProvider)
          .createSession(
            title: _title.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            whatsappGroupUrl: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
            slots: [
              for (var i = 0; i < _assignees.length; i++)
                (userId: _assignees[i]!, startsAt: _slotStart(i), endsAt: _slotStart(i + 1)),
            ],
          );
      if (mounted) context.pushReplacement('/session-priere/$uuid');
    } catch (e) {
      _snack('Enregistrement impossible : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(_intercessorsProvider).valueOrNull ?? const <PrayerPerson>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Planifier une chaîne')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          HFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(icon: Icons.local_fire_department_outlined, title: 'La chaîne'),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Sujet de prière (facultatif)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _whatsapp,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Lien du groupe WhatsApp (facultatif)',
                    hintText: 'https://chat.whatsapp.com/…',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(icon: Icons.schedule, title: 'Horaires'),
                OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.event),
                  label: Text('Début : ${formatDateTime(_start)}'),
                ),
                const SizedBox(height: 12),
                const Text('Durée de chaque créneau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [30, 45, 60, 90, 120])
                      QuickChip(
                        label: m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}',
                        selected: _slotMinutes == m,
                        onTap: () => setState(() => _slotMinutes = m),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HFCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  icon: Icons.groups_outlined,
                  title: 'Créneaux',
                  trailing: Pill('Fin ${formatTime(_slotStart(_assignees.length))}', bg: HF.sand),
                ),
                for (var i = 0; i < _assignees.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            '${formatTime(_slotStart(i))} – ${formatTime(_slotStart(i + 1))}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _assignees[i],
                            isExpanded: true,
                            hint: const Text('Intercesseur'),
                            items: [
                              for (final p in people)
                                DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _assignees[i] = v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retirer',
                          onPressed: _assignees.length <= 1 ? null : () => setState(() => _assignees.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _assignees.add(null)),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un créneau'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Publier le planning'),
          ),
        ],
      ),
    );
  }
}
