import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/collection_store.dart';
import '../data/recovery_settings_store.dart';
import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/recovery_score.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/form_helpers.dart';
import 'recovery_habits_card.dart';
import 'recovery_mobility_tab.dart';
import 'recovery_score_widgets.dart';
import 'recovery_tabs.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    this.sleep,
    this.wellness,
    this.notes,
    this.mobility,
    this.habits,
    this.settings,
    this.clock,
  });

  final CollectionStore<SleepEntry>? sleep;
  final CollectionStore<WellnessEntry>? wellness;
  final CollectionStore<RecoveryNote>? notes;
  final CollectionStore<MobilityEntry>? mobility;
  final CollectionStore<RecoveryHabitDay>? habits;
  final RecoverySettingsStore? settings;
  final DateTime Function()? clock;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen>
    with WidgetsBindingObserver {
  int tab = 0;
  late final ValueNotifier<DateTime> _day;
  Timer? _midnight;

  DateTime _now() => (widget.clock?.call() ?? DateTime.now()).toLocal();

  @override
  void initState() {
    super.initState();
    _day = ValueNotifier(DateUtils.dateOnly(_now()));
    WidgetsBinding.instance.addObserver(this);
    _updateDay();
  }

  void _updateDay() {
    _midnight?.cancel();
    final now = _now();
    _day.value = DateUtils.dateOnly(now);
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(nextDay.difference(now), _updateDay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateDay();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _day.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleep = widget.sleep ?? sleepStore;
    final wellness = widget.wellness ?? wellnessStore;
    final notes = widget.notes ?? noteStore;
    final mobility = widget.mobility ?? mobilityStore;
    final habits = widget.habits ?? recoveryHabitStore;
    final settings = widget.settings ?? recoverySettingsStore;
    return ListenableBuilder(
      listenable: Listenable.merge([
        settings,
        if (tab == 0) ...[sleep, wellness, notes, _day],
      ]),
      builder: (context, _) => ScreenScaffold(
        title: 'Recovery',
        color: AppColors.recovery,
        actionIcon: Icons.settings,
        onAction: () => context.push('/recovery/settings'),
        tabs: const ['Overview', 'Sleep', 'Wellness', 'Notes', 'Mobility'],
        responsiveTabs: true,
        tab: tab,
        onTab: (i) => setState(() => tab = i),
        children: switch (tab) {
          1 => [RecoverySleepTab(store: sleep, settings: settings.settings)],
          2 => [RecoveryWellnessTab(store: wellness)],
          3 => [RecoveryNotesTab(store: notes)],
          4 => [RecoveryMobilityTab(store: mobility)],
          _ => _overview(
            context,
            sleep,
            wellness,
            notes,
            mobility,
            habits,
            settings,
          ),
        },
      ),
    );
  }

  List<Widget> _overview(
    BuildContext context,
    CollectionStore<SleepEntry> sleep,
    CollectionStore<WellnessEntry> wellness,
    CollectionStore<RecoveryNote> notes,
    CollectionStore<MobilityEntry> mobility,
    CollectionStore<RecoveryHabitDay> habits,
    RecoverySettingsStore settingsStore,
  ) {
    final assessment = readRecoveryAssessment(sleep, wellness, settingsStore);
    final lastNight = assessment.sleep;
    final settings = settingsStore.settings;
    final recentNote = notes.items.firstOrNull;
    return [
      AppCard(
        child: Row(
          children: [
            const Icon(
              Icons.nightlight_round,
              color: AppColors.recovery,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep Last Night',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    sleep.loading
                        ? 'Loading sleep…'
                        : sleep.error ??
                              (lastNight == null
                                  ? 'No sleep logged for last night'
                                  : hoursLabel(lastNight.hours)),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    settingsStore.loading
                        ? 'Loading goal…'
                        : settingsStore.error ??
                              (settings == null
                                  ? 'Goal unavailable'
                                  : 'Goal: ${settings.sleepGoalLabel}'),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (lastNight != null &&
                      settings != null &&
                      sleep.error == null)
                    ProgressBar(
                      (lastNight.hours / settings.sleepGoalHours)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                      AppColors.recovery,
                    )
                  else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      SectionHeader(
        'Recovery Score',
        action: 'View Details',
        onAction: () => context.push('/recovery/details'),
      ),
      AppCard(
        child: Row(
          children: [
            RecoveryScoreRing(assessment: assessment),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final component in assessment.components)
                    _Metric(
                      switch (component.measure) {
                        RecoveryMeasure.sleep => Icons.nightlight_round,
                        RecoveryMeasure.energy => Icons.bolt,
                        RecoveryMeasure.soreness => Icons.accessibility_new,
                        RecoveryMeasure.mood => Icons.emoji_emotions,
                      },
                      component.measure.label,
                      recoveryValue(component),
                    ),
                  if (assessment.sleepQuality case final quality?)
                    _Metric(
                      Icons.bedtime_outlined,
                      'Sleep quality',
                      '$quality / 5',
                    ),
                  if (settings?.showHrv != false)
                    _Metric(
                      Icons.favorite,
                      'HRV',
                      assessment.hrv == null ? '—' : '${assessment.hrv} ms',
                    ),
                  _Metric(
                    Icons.insights,
                    'Overall',
                    assessment.rating?.label ?? '—',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuickTile(
              Icons.bed,
              'Log Sleep',
              AppColors.recovery,
              onTap: () => showLogSleepForm(context, sleep),
            ),
            QuickTile(
              Icons.favorite,
              'Log Wellness',
              Colors.red,
              onTap: () => showLogWellnessForm(context, wellness),
            ),
            QuickTile(
              Icons.self_improvement,
              'Mobility / Stretching',
              Colors.blue,
              onTap: () => showMobilityForm(context, mobility),
            ),
            QuickTile(
              Icons.note_add,
              'Add Note',
              Colors.amber.shade800,
              onTap: () => showAddRecoveryNoteForm(context, notes),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      RecoveryHabitsCard(
        day: _day,
        sleep: sleep,
        wellness: wellness,
        mobility: mobility,
        notes: notes,
        habits: habits,
      ),
      const SectionHeader('This Week', action: 'View All'),
      Row(
        children: [
          const _Trend('Avg Sleep'),
          const _Trend('Avg Energy'),
          const _Trend('Avg Soreness'),
          _Trend('Avg HRV', hidden: settings?.showHrv == false),
        ],
      ),
      SectionHeader(
        'Recent Notes',
        action: 'View All',
        onAction: () => setState(() => tab = 3),
      ),
      AppCard(
        child: Row(
          children: [
            const Icon(Icons.description, color: AppColors.recovery, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.loading)
                    const Text('Loading recovery notes…')
                  else if (notes.error case final error?)
                    Text(error)
                  else if (recentNote == null)
                    const Text('No recovery notes yet.')
                  else ...[
                    Text(
                      formatDate(recentNote.date.toLocal()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      recentNote.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(recentNote.body),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Metric(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.recovery),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(value, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend(this.label, {this.hidden = false});

  final String label;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hidden ? 'Hidden' : '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Divider(height: 1, color: Colors.black12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
