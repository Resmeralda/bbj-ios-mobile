import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/recovery_settings_store.dart';
import '../models/recovery_settings.dart';
import '../theme.dart';

class RecoverySettingsScreen extends StatelessWidget {
  const RecoverySettingsScreen({super.key, this.store});

  final RecoverySettingsStore? store;

  @override
  Widget build(BuildContext context) {
    final settingsStore = store ?? recoverySettingsStore;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Settings'),
        backgroundColor: AppColors.recovery,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: settingsStore,
        builder: (context, _) {
          if (settingsStore.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settingsStore.error case final error?) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error),
                  TextButton(
                    onPressed: settingsStore.load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final settings = settingsStore.settings;
          if (settings == null) {
            return const Center(
              child: Text('Sign in to edit recovery settings.'),
            );
          }
          return _SettingsForm(
            key: ObjectKey(settingsStore.account),
            store: settingsStore,
            account: settingsStore.account,
            initial: settings,
          );
        },
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    super.key,
    required this.store,
    required this.account,
    required this.initial,
  });

  final RecoverySettingsStore store;
  final Object account;
  final RecoverySettings initial;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _hours = TextEditingController(
    text: widget.initial.sleepGoalHours.toString(),
  );
  late bool _showHrv = widget.initial.showHrv;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(
        RecoverySettings(
          sleepGoalHours: double.parse(_hours.text),
          showHrv: _showHrv,
        ),
        account: widget.account,
      );
    } catch (_) {
      if (!mounted || widget.store.account != widget.account) return;
      setState(() {
        _saving = false;
        _error = 'Could not save recovery settings. Please try again.';
      });
      return;
    }
    if (!mounted || widget.store.account != widget.account) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Recovery settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _hours,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Sleep goal (hours)'),
          validator: (value) =>
              RecoverySettings.isValidSleepGoal(double.tryParse(value ?? ''))
              ? null
              : 'Enter a sleep goal between 1 and 24 hours',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show HRV summaries'),
          value: _showHrv,
          onChanged: _saving
              ? null
              : (value) => setState(() => _showHrv = value),
        ),
        if (_error case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.recovery),
          child: Text(_saving ? 'Saving…' : 'Save Settings'),
        ),
      ],
    ),
  );
}
