import 'package:flutter/material.dart';

import '../data/collection_store.dart';
import '../data/recovery_settings_store.dart';
import '../models/health_models.dart';
import '../models/recovery_score.dart';
import '../models/training_session.dart' show formatHours;
import '../theme.dart';

RecoveryAssessment readRecoveryAssessment(
  CollectionStore<SleepEntry> sleep,
  CollectionStore<WellnessEntry> wellness,
  RecoverySettingsStore settings,
) => RecoveryAssessment.forDay(
  day: DateTime.now(),
  sleepEntries: !sleep.loading && sleep.error == null ? sleep.items : const [],
  wellnessEntries: !wellness.loading && wellness.error == null
      ? wellness.items
      : const [],
  settings: !settings.loading && settings.error == null
      ? settings.settings
      : null,
);

String recoveryValue(RecoveryComponent component, {String missing = '—'}) {
  final value = component.value;
  if (value == null) return missing;
  return component.measure == RecoveryMeasure.sleep
      ? formatHours(value.toDouble())
      : '$value / 5';
}

class RecoveryScoreRing extends StatelessWidget {
  const RecoveryScoreRing({super.key, required this.assessment});

  final RecoveryAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final score = assessment.score;
    final rating = assessment.rating;
    final color = switch (rating) {
      RecoveryRating.low => Colors.red,
      RecoveryRating.moderate => Colors.amber,
      RecoveryRating.high => Colors.green,
      null => Colors.grey,
    };
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: ExcludeSemantics(
              excluding: score == null,
              child: CircularProgressIndicator(
                value: score == null ? 0 : score / 100,
                strokeWidth: 12,
                color: color,
                backgroundColor: score == null ? Colors.grey : Colors.black12,
                semanticsLabel: 'Recovery score',
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                rating?.label ?? 'Unavailable',
                style: TextStyle(
                  color: rating == null ? AppColors.muted : color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
