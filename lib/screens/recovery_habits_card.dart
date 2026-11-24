import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/collection_store.dart';
import '../models/health_models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';

class RecoveryHabitsCard extends StatelessWidget {
  const RecoveryHabitsCard({
    super.key,
    required this.day,
    required this.sleep,
    required this.wellness,
    required this.mobility,
    required this.notes,
    required this.habits,
  });

  final ValueListenable<DateTime> day;
  final CollectionStore<SleepEntry> sleep;
  final CollectionStore<WellnessEntry> wellness;
  final CollectionStore<MobilityEntry> mobility;
  final CollectionStore<RecoveryNote> notes;
  final CollectionStore<RecoveryHabitDay> habits;

  bool _recorded<T>(CollectionStore<T> store, DateTime Function(T) dateOf) =>
      store.items.any(
        (entry) => DateUtils.isSameDay(dateOf(entry).toLocal(), day.value),
      );

  @override
  Widget build(BuildContext context) {
    final changes = Listenable.merge([
      day,
      sleep,
      wellness,
      mobility,
      notes,
      habits,
    ]);
    return ListenableBuilder(
      listenable: changes,
      builder: (context, _) {
        final (automatic, windDown, loading, error) = _readHabits();
        final completed =
            automatic.values.where((done) => done).length + (windDown ? 1 : 0);
        final total = automatic.length + 1;
        return AppCard(
          onTap: () => showFormSheet(
            context,
            ListenableBuilder(listenable: changes, builder: _checklist),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist, color: AppColors.recovery, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                flex: 2,
                child: Text(
                  'Recovery Habits',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      loading
                          ? 'Loading habits…'
                          : error != null
                          ? 'Habits sync issue'
                          : '$completed of $total completed',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12),
                    ),
                    ProgressBar(completed / total, AppColors.recovery),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.recovery),
            ],
          ),
        );
      },
    );
  }

  (Map<String, bool>, bool, bool, String?) _readHabits() {
    final today = RecoveryHabitDay.idFor(day.value);
    return (
      {
        'Log last night’s sleep': _recorded(sleep, (entry) => entry.date),
        'Log wellness': _recorded(wellness, (entry) => entry.date),
        'Log mobility': _recorded(mobility, (entry) => entry.date),
        'Add a recovery note': _recorded(notes, (entry) => entry.date),
      },
      habits.items.any((entry) => entry.id == today && entry.windDown),
      sleep.loading ||
          wellness.loading ||
          mobility.loading ||
          notes.loading ||
          habits.loading,
      sleep.error ??
          wellness.error ??
          mobility.error ??
          notes.error ??
          habits.error,
    );
  }

  Widget _checklist(BuildContext context, Widget? child) {
    final (automatic, windDown, loading, error) = _readHabits();
    final account = habits.account;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Daily Recovery Habits'),
        Text(RecoveryHabitDay.idFor(day.value)),
        if (loading) const Text('Loading habits…'),
        if (error != null) Text(error),
        const SizedBox(height: 8),
        const Text('The first four habits update from your logs.'),
        for (final entry in automatic.entries)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            value: entry.value,
            onChanged: null,
          ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Wind-down'),
          value: windDown,
          activeColor: AppColors.recovery,
          onChanged: habits.loading
              ? null
              : (value) {
                  if (account != habits.account) return;
                  habits.save(
                    RecoveryHabitDay(
                      id: RecoveryHabitDay.idFor(day.value),
                      windDown: value == true,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
