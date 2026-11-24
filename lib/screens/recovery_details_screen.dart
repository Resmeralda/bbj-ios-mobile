import 'package:flutter/material.dart';

import '../data/collection_store.dart';
import '../data/recovery_settings_store.dart';
import '../data/stores.dart';
import '../models/health_models.dart';
import '../models/recovery_score.dart';
import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import '../widgets/common.dart';
import 'recovery_score_widgets.dart';

class RecoveryDetailsScreen extends StatelessWidget {
  const RecoveryDetailsScreen({
    super.key,
    this.sleep,
    this.wellness,
    this.settings,
  });

  final CollectionStore<SleepEntry>? sleep;
  final CollectionStore<WellnessEntry>? wellness;
  final RecoverySettingsStore? settings;

  @override
  Widget build(BuildContext context) {
    final sleepRecords = sleep ?? sleepStore;
    final wellnessRecords = wellness ?? wellnessStore;
    final preferences = settings ?? recoverySettingsStore;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Details'),
        backgroundColor: AppColors.recovery,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          sleepRecords,
          wellnessRecords,
          preferences,
        ]),
        builder: (context, _) {
          final assessment = readRecoveryAssessment(
            sleepRecords,
            wellnessRecords,
            preferences,
          );
          final loading =
              sleepRecords.loading ||
              wellnessRecords.loading ||
              preferences.loading;
          final errors = [
            sleepRecords.error,
            wellnessRecords.error,
            preferences.error,
          ].whereType<String>().toSet();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    RecoveryScoreRing(assessment: assessment),
                    const SizedBox(height: 12),
                    if (loading)
                      const Text('Loading recovery measurements…')
                    else if (errors.isNotEmpty)
                      ...errors.map((error) => Text(error))
                    else if (assessment.score == null)
                      const Text(
                        'A sleep entry, sleep goal, and today’s energy, soreness and mood are needed for a score.',
                      ),
                  ],
                ),
              ),
              const SectionHeader('Score contributions'),
              for (final component in assessment.components)
                _Contribution(component: component, assessment: assessment),
              if (assessment.sleepQuality != null ||
                  (assessment.settings?.showHrv != false &&
                      assessment.hrv != null)) ...[
                const SectionHeader('Additional measurements'),
                if (assessment.sleepQuality case final quality?)
                  AppCard(
                    child: Text(
                      'Sleep quality: $quality / 5 • ${formatDate(assessment.sleep!.date.toLocal())}',
                    ),
                  ),
                if (assessment.settings?.showHrv != false &&
                    assessment.hrv != null)
                  AppCard(
                    child: Text(
                      'HRV: ${assessment.hrv} ms • ${formatDate(assessment.wellness!.date.toLocal())}',
                    ),
                  ),
              ],
              const SectionHeader('How it is calculated'),
              const _ScoreGuide(),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreGuide extends StatelessWidget {
  const _ScoreGuide();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Four equally weighted factors contribute to your score.'),
        const SizedBox(height: 8),
        for (final (measure, icon) in const [
          (RecoveryMeasure.sleep, Icons.nightlight_round),
          (RecoveryMeasure.energy, Icons.bolt),
          (RecoveryMeasure.soreness, Icons.accessibility_new),
          (RecoveryMeasure.mood, Icons.emoji_emotions),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.recovery),
                const SizedBox(width: 8),
                Expanded(child: Text(measure.label)),
                const Text(
                  '25 points',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          spacing: 6,
          children: [
            for (final (rating, range, color) in const [
              (RecoveryRating.low, '0–39', Colors.red),
              (RecoveryRating.moderate, '40–69', Colors.amber),
              (RecoveryRating.high, '70–100', Colors.green),
            ])
              Expanded(
                child: Column(
                  children: [
                    Container(height: 4, color: color),
                    const SizedBox(height: 4),
                    Text(
                      rating.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(range, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Higher energy, better sleep, positive mood, and lower soreness improve your score.',
        ),
        const SizedBox(height: 6),
        const Text(
          'This score is a wellness estimate, not a medical assessment.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _Contribution extends StatelessWidget {
  const _Contribution({required this.component, required this.assessment});

  final RecoveryComponent component;
  final RecoveryAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final value = recoveryValue(component, missing: 'Not logged');
    final fraction = component.fraction;
    final goal = assessment.settings?.sleepGoalLabel;
    final showGoal =
        component.measure == RecoveryMeasure.sleep &&
        component.value != null &&
        goal != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            component.measure.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(showGoal ? '$value / $goal' : value),
          if (component.value != null)
            Text('Recorded ${formatDate(component.date!.toLocal())}'),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            ProgressBar(fraction, AppColors.recovery),
            Text(
              '${(fraction * 100).round()}% • ${component.points!.toStringAsFixed(1)} / 25 points',
            ),
          ] else if (component.value != null)
            const Text('Sleep goal unavailable'),
        ],
      ),
    );
  }
}
