import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/training_session.dart';
import '../session_store.dart';
import '../theme.dart';
import '../widgets/form_helpers.dart';

/// Logs a new session, or edits one when [session] is provided.
class LogSessionScreen extends StatefulWidget {
  final TrainingSession? session;
  final SessionStore? store;
  const LogSessionScreen({super.key, this.session, this.store});
  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  final _form = GlobalKey<FormState>();
  SessionStore get _store => widget.store ?? sessionStore;
  late final Object _account;
  late String type;
  late DateTime date;
  late TimeOfDay time;
  late final TextEditingController duration;
  late final TextEditingController rounds;
  late final TextEditingController techniques;
  late final TextEditingController notes;

  bool get editing => widget.session != null;

  @override
  void initState() {
    super.initState();
    _account = _store.account;
    final s = widget.session;
    type = s?.type ?? sessionTypes.first;
    date = s?.date ?? DateTime.now();
    time = TimeOfDay.fromDateTime(s?.date ?? DateTime.now());
    duration = TextEditingController(text: (s?.hours ?? 1.5).toString());
    rounds = TextEditingController(text: (s?.rounds ?? 0).toString());
    techniques = TextEditingController(text: s?.techniques ?? '');
    notes = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    duration.dispose();
    rounds.dispose();
    techniques.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: time);
    if (t != null) setState(() => time = t);
  }

  void _save() {
    if (!isCurrentFormAccount(context, _account, _store.account)) return;
    if (!_form.currentState!.validate()) return;
    final when = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final base = widget.session;
    final s = TrainingSession(
      id: base?.id ?? _store.newId(),
      type: type,
      date: when,
      hours: double.parse(duration.text),
      rounds: int.tryParse(rounds.text) ?? 0,
      techniques: techniques.text.trim(),
      notes: notes.text.trim(),
    );
    editing ? _store.update(s) : _store.add(s);
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true &&
        mounted &&
        isCurrentFormAccount(context, _account, _store.account)) {
      _store.delete(widget.session!.id);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(editing ? 'Edit Session' : 'Log Training Session'),
      backgroundColor: AppColors.training,
      foregroundColor: Colors.white,
      actions: [
        if (editing)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
      ],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Session type'),
            items: sessionTypes
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => type = v!),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(formatDate(date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start time'),
            subtitle: Text(time.format(context)),
            trailing: const Icon(Icons.schedule),
            onTap: _pickTime,
          ),
          TextFormField(
            controller: duration,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Duration (hours)'),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return (n == null || n <= 0) ? 'Enter a number above 0' : null;
            },
          ),
          TextFormField(
            controller: rounds,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sparring rounds'),
          ),
          TextFormField(
            controller: techniques,
            decoration: const InputDecoration(
              labelText: 'Techniques practiced',
              hintText: 'Guard passing, side control',
            ),
          ),
          TextFormField(
            controller: notes,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.home,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _save,
            child: Text(editing ? 'Save Changes' : 'Save Session'),
          ),
        ],
      ),
    ),
  );
}
