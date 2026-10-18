import 'package:flutter/material.dart';

import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';

const _sleepGoalHours = 8.0;

double _avg(Iterable<int> v) =>
    v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

// ───────────────────────── Sleep ─────────────────────────

class RecoverySleepTab extends StatelessWidget {
  const RecoverySleepTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sleepStore,
    builder: (context, _) {
      final entries = sleepStore.items; // newest first
      final last = entries.isEmpty ? null : entries.first;
      final week = entries.take(7).toList();
      final avg = week.isEmpty
          ? null
          : week.fold<double>(0, (a, e) => a + e.hours) / week.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Log Sleep',
            icon: Icons.bed,
            color: AppColors.recovery,
            onPressed: () => showFormSheet(context, const _SleepForm()),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last sleep', style: TextStyle(fontSize: 12)),
                Text(
                  last == null ? '—' : hoursLabel(last.hours),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(
                  last == null ? 0 : last.hours / _sleepGoalHours,
                  AppColors.recovery,
                ),
                const SizedBox(height: 4),
                Text(
                  avg == null
                      ? 'Goal: ${_sleepGoalHours.round()} hr'
                      : 'Goal: ${_sleepGoalHours.round()} hr  •  '
                            '${week.length}-entry average: ${hoursLabel(avg)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SectionHeader('History'),
          if (sleepStore.error != null) EmptyState(sleepStore.error!),
          if (entries.isEmpty && sleepStore.error == null)
            EmptyState(
              sleepStore.loading
                  ? 'Loading…'
                  : 'No sleep logged yet. Tap Log Sleep to add a night.',
            ),
          for (final e in entries)
            EntryTile(
              icon: Icons.nightlight_round,
              color: AppColors.recovery,
              title: hoursLabel(e.hours),
              subtitle: '${formatDate(e.date)}  •  Quality ${e.quality}/5',
              extra: e.notes,
              onTap: () => showFormSheet(context, _SleepForm(existing: e)),
              onDelete: () async {
                if (await confirmDelete(context, 'sleep entry')) {
                  sleepStore.delete(e.id);
                }
              },
            ),
        ],
      );
    },
  );
}

class _SleepForm extends StatefulWidget {
  final SleepEntry? existing;
  const _SleepForm({this.existing});
  @override
  State<_SleepForm> createState() => _SleepFormState();
}

class _SleepFormState extends State<_SleepForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController hours, notes;
  late DateTime date;
  late int quality;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    hours = TextEditingController(text: e == null ? '' : e.hours.toString());
    notes = TextEditingController(text: e?.notes ?? '');
    date = e?.date ?? DateTime.now();
    quality = e?.quality ?? 3;
  }

  @override
  void dispose() {
    hours.dispose();
    notes.dispose();
    super.dispose();
  }

  String? _hoursValidator(String? v) {
    final n = double.tryParse(v ?? '');
    return (n == null || n <= 0 || n > 24)
        ? 'Enter hours between 0 and 24'
        : null;
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    sleepStore.save(
      SleepEntry(
        id: widget.existing?.id ?? sleepStore.newId(),
        date: date,
        hours: double.parse(hours.text),
        quality: quality,
        notes: notes.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Log sleep' : 'Edit sleep'),
        DateField(date: date, onChanged: (d) => setState(() => date = d)),
        TextFormField(
          controller: hours,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Hours slept'),
          validator: _hoursValidator,
        ),
        RatingPicker(
          label: 'Sleep quality',
          low: 'Poor',
          high: 'Great',
          value: quality,
          onChanged: (v) => setState(() => quality = v),
        ),
        TextFormField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.recovery,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ───────────────────────── Wellness ─────────────────────────

class RecoveryWellnessTab extends StatelessWidget {
  const RecoveryWellnessTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: wellnessStore,
    builder: (context, _) {
      final entries = wellnessStore.items; // newest first
      final week = entries.take(7).toList();
      String avg(int Function(WellnessEntry) f) =>
          week.isEmpty ? '—' : oneDecimal(_avg(week.map(f)));
      final hrvs = [
        for (final e in week)
          if (e.hrv != null) e.hrv!,
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Log Wellness',
            icon: Icons.favorite,
            color: AppColors.recovery,
            onPressed: () => showFormSheet(context, const _WellnessForm()),
          ),
          StatRow([
            StatCard('Energy', avg((e) => e.energy)),
            StatCard('Soreness', avg((e) => e.soreness)),
            StatCard('Mood', avg((e) => e.mood)),
            StatCard('HRV', hrvs.isEmpty ? '—' : '${_avg(hrvs).round()} ms'),
          ]),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Averages of your last 7 check-ins. Energy, soreness and mood '
              'are rated 1 to 5; HRV is optional.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          const SectionHeader('History'),
          if (wellnessStore.error != null) EmptyState(wellnessStore.error!),
          if (entries.isEmpty && wellnessStore.error == null)
            EmptyState(
              wellnessStore.loading
                  ? 'Loading…'
                  : 'No check-ins yet. Tap Log Wellness to add one.',
            ),
          for (final e in entries)
            EntryTile(
              icon: Icons.favorite,
              color: Colors.red,
              title:
                  'Energy ${e.energy}  •  Soreness ${e.soreness}  •  Mood ${e.mood}',
              subtitle: e.hrv == null
                  ? formatDate(e.date)
                  : '${formatDate(e.date)}  •  HRV ${e.hrv} ms',
              extra: e.notes,
              onTap: () => showFormSheet(context, _WellnessForm(existing: e)),
              onDelete: () async {
                if (await confirmDelete(context, 'check-in')) {
                  wellnessStore.delete(e.id);
                }
              },
            ),
        ],
      );
    },
  );
}

class _WellnessForm extends StatefulWidget {
  final WellnessEntry? existing;
  const _WellnessForm({this.existing});
  @override
  State<_WellnessForm> createState() => _WellnessFormState();
}

class _WellnessFormState extends State<_WellnessForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController notes, hrv;
  late DateTime date;
  late int energy, soreness, mood;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    notes = TextEditingController(text: e?.notes ?? '');
    hrv = TextEditingController(text: e?.hrv == null ? '' : '${e!.hrv}');
    date = e?.date ?? DateTime.now();
    energy = e?.energy ?? 3;
    soreness = e?.soreness ?? 3;
    mood = e?.mood ?? 3;
  }

  @override
  void dispose() {
    notes.dispose();
    hrv.dispose();
    super.dispose();
  }

  String? _hrvValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final n = double.tryParse(v);
    return (n == null || n <= 0 || n > 300)
        ? 'Enter HRV between 1 and 300 ms'
        : null;
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final hrvText = hrv.text.trim();
    wellnessStore.save(
      WellnessEntry(
        id: widget.existing?.id ?? wellnessStore.newId(),
        date: date,
        energy: energy,
        soreness: soreness,
        mood: mood,
        hrv: hrvText.isEmpty ? null : double.parse(hrvText).round(),
        notes: notes.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Log wellness' : 'Edit wellness'),
        DateField(date: date, onChanged: (d) => setState(() => date = d)),
        RatingPicker(
          label: 'Energy',
          low: 'Drained',
          high: 'Energized',
          value: energy,
          onChanged: (v) => setState(() => energy = v),
        ),
        RatingPicker(
          label: 'Soreness',
          low: 'None',
          high: 'Very sore',
          value: soreness,
          onChanged: (v) => setState(() => soreness = v),
        ),
        RatingPicker(
          label: 'Mood',
          low: 'Low',
          high: 'Great',
          value: mood,
          onChanged: (v) => setState(() => mood = v),
        ),
        TextFormField(
          controller: hrv,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'HRV in ms (optional)',
            helperText: 'From your watch or HRV app, if you track it',
          ),
          validator: _hrvValidator,
        ),
        TextFormField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.recovery,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ───────────────────────── Notes ─────────────────────────

class RecoveryNotesTab extends StatelessWidget {
  const RecoveryNotesTab({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: noteStore,
    builder: (context, _) {
      final notes = noteStore.items; // newest first
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Add Note',
            icon: Icons.note_add,
            color: AppColors.recovery,
            onPressed: () => showFormSheet(context, const _NoteForm()),
          ),
          if (noteStore.error != null) EmptyState(noteStore.error!),
          if (notes.isEmpty && noteStore.error == null)
            EmptyState(
              noteStore.loading
                  ? 'Loading…'
                  : 'No notes yet. Tap Add Note to write one.',
            ),
          for (final n in notes)
            EntryTile(
              icon: Icons.description,
              color: AppColors.recovery,
              title: n.title,
              subtitle: formatDate(n.date),
              extra: n.body,
              onTap: () => showFormSheet(context, _NoteForm(existing: n)),
              onDelete: () async {
                if (await confirmDelete(context, 'note')) {
                  noteStore.delete(n.id);
                }
              },
            ),
        ],
      );
    },
  );
}

class _NoteForm extends StatefulWidget {
  final RecoveryNote? existing;
  const _NoteForm({this.existing});
  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController title, body;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    title = TextEditingController(text: n?.title ?? '');
    body = TextEditingController(text: n?.body ?? '');
    date = n?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    noteStore.save(
      RecoveryNote(
        id: widget.existing?.id ?? noteStore.newId(),
        date: date,
        title: title.text.trim(),
        body: body.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _key,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.existing == null ? 'Add note' : 'Edit note'),
        DateField(date: date, onChanged: (d) => setState(() => date = d)),
        TextFormField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => requiredText(v, 'Please enter a title'),
        ),
        TextFormField(
          controller: body,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.recovery,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _save,
          child: const Text('Save Note'),
        ),
      ],
    ),
  );
}
