import 'package:flutter/material.dart';

import '../data/collection_store.dart';
import '../models/health_models.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';

void showMobilityForm(
  BuildContext context,
  CollectionStore<MobilityEntry> store, {
  MobilityEntry? entry,
}) => showFormSheet(context, _MobilityForm(store: store, entry: entry));

class RecoveryMobilityTab extends StatelessWidget {
  const RecoveryMobilityTab({super.key, required this.store});

  final CollectionStore<MobilityEntry> store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final entries = store.items;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddButton(
            label: 'Log Mobility',
            icon: Icons.self_improvement,
            color: AppColors.recovery,
            onPressed: () => showMobilityForm(context, store),
          ),
          const SectionHeader('History'),
          if (store.loading)
            const EmptyState('Loading mobility activities…')
          else if (store.error case final error?)
            EmptyState(error)
          else if (entries.isEmpty)
            const EmptyState('No mobility activities yet.'),
          for (final entry in entries)
            EntryTile(
              icon: Icons.self_improvement,
              color: AppColors.recovery,
              title: '${entry.activity.label} • ${entry.minutes} min',
              subtitle: [
                formatDate(entry.date.toLocal()),
                if (entry.bodyArea.isNotEmpty) entry.bodyArea,
              ].join(' • '),
              extra: entry.notes,
              onTap: () => showMobilityForm(context, store, entry: entry),
              onDelete: () async {
                final account = store.account;
                if (await confirmDelete(context, 'mobility activity') &&
                    account == store.account) {
                  store.delete(entry.id);
                }
              },
            ),
        ],
      );
    },
  );
}

class _MobilityForm extends StatefulWidget {
  const _MobilityForm({required this.store, required this.entry});

  final CollectionStore<MobilityEntry> store;
  final MobilityEntry? entry;

  @override
  State<_MobilityForm> createState() => _MobilityFormState();
}

class _MobilityFormState extends State<_MobilityForm> {
  final _form = GlobalKey<FormState>();
  late final Object _account;
  late DateTime _date = widget.entry?.date.toLocal() ?? DateTime.now();
  late MobilityActivity _activity =
      widget.entry?.activity ?? MobilityActivity.stretching;
  late final _minutes = TextEditingController(
    text: widget.entry?.minutes.toString(),
  );
  late final _bodyArea = TextEditingController(text: widget.entry?.bodyArea);
  late final _notes = TextEditingController(text: widget.entry?.notes);

  @override
  void initState() {
    super.initState();
    _account = widget.store.account;
  }

  @override
  void dispose() {
    _minutes.dispose();
    _bodyArea.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (_account != widget.store.account) {
      Navigator.of(context).pop();
      return;
    }
    if (!_form.currentState!.validate()) return;
    widget.store.save(
      MobilityEntry(
        id: widget.entry?.id ?? widget.store.newId(),
        date: _date,
        activity: _activity,
        minutes: int.parse(_minutes.text.trim()),
        bodyArea: _bodyArea.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(widget.entry == null ? 'Log mobility' : 'Edit mobility'),
        DateField(
          date: _date,
          onChanged: (date) => setState(() => _date = date),
        ),
        DropdownButtonFormField<MobilityActivity>(
          isExpanded: true,
          initialValue: _activity,
          decoration: const InputDecoration(labelText: 'Activity type'),
          items: [
            for (final activity in MobilityActivity.values)
              DropdownMenuItem(value: activity, child: Text(activity.label)),
          ],
          onChanged: (activity) => setState(() => _activity = activity!),
        ),
        TextFormField(
          controller: _minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Duration (minutes)'),
          validator: (value) =>
              MobilityEntry.validMinutes(int.tryParse(value?.trim() ?? ''))
              ? null
              : 'Enter a positive whole number of minutes',
        ),
        TextFormField(
          controller: _bodyArea,
          decoration: const InputDecoration(labelText: 'Body area (optional)'),
        ),
        TextFormField(
          controller: _notes,
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
