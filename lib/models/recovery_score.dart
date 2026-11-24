import 'health_models.dart';
import 'recovery_settings.dart';

enum RecoveryRating {
  low('Low'),
  moderate('Moderate'),
  high('High');

  const RecoveryRating(this.label);
  final String label;

  static RecoveryRating forScore(int score) => switch (score) {
    < 40 => low,
    < 70 => moderate,
    _ => high,
  };
}

enum RecoveryMeasure {
  sleep('Sleep'),
  energy('Energy'),
  soreness('Soreness'),
  mood('Mood');

  const RecoveryMeasure(this.label);
  final String label;
}

class RecoveryComponent {
  const RecoveryComponent(this.measure, this.value, this.date, this.fraction);

  final RecoveryMeasure measure;
  final num? value;
  final DateTime? date;
  final double? fraction;

  double? get points => fraction == null ? null : 25 * fraction!;
}

class RecoveryAssessment {
  const RecoveryAssessment._({
    required this.sleep,
    required this.wellness,
    required this.settings,
    required this.components,
  });

  final SleepEntry? sleep;
  final WellnessEntry? wellness;
  final RecoverySettings? settings;
  final List<RecoveryComponent> components;

  int? get score {
    final points = components
        .map((component) => component.points)
        .whereType<double>();
    return points.length == components.length
        ? points.reduce((total, value) => total + value).round()
        : null;
  }

  RecoveryRating? get rating {
    final value = score;
    return value == null ? null : RecoveryRating.forScore(value);
  }

  int? get sleepQuality => _rating(sleep?.quality);

  int? get hrv {
    final value = wellness?.hrv;
    return WellnessEntry.validHrv(value?.toDouble()) ? value : null;
  }

  factory RecoveryAssessment.forDay({
    required DateTime day,
    required Iterable<SleepEntry> sleepEntries,
    required Iterable<WellnessEntry> wellnessEntries,
    required RecoverySettings? settings,
  }) {
    final sleep = _latestOn(
      day,
      sleepEntries.where((entry) => SleepEntry.validHours(entry.hours)),
      (entry) => entry.date,
    );
    final wellness = _latestOn(day, wellnessEntries, (entry) => entry.date);
    final hours = sleep?.hours;
    final goal = settings?.sleepGoalHours;

    RecoveryComponent wellnessComponent(RecoveryMeasure measure, int? raw) {
      final value = _rating(raw);
      final fraction = value == null
          ? null
          : (measure == RecoveryMeasure.soreness ? 5 - value : value - 1) / 4;
      return RecoveryComponent(measure, value, wellness?.date, fraction);
    }

    return RecoveryAssessment._(
      sleep: sleep,
      wellness: wellness,
      settings: settings,
      components: List.unmodifiable([
        RecoveryComponent(
          RecoveryMeasure.sleep,
          hours,
          sleep?.date,
          hours != null && RecoverySettings.isValidSleepGoal(goal)
              ? (hours / goal!).clamp(0.0, 1.0).toDouble()
              : null,
        ),
        wellnessComponent(RecoveryMeasure.energy, wellness?.energy),
        wellnessComponent(RecoveryMeasure.soreness, wellness?.soreness),
        wellnessComponent(RecoveryMeasure.mood, wellness?.mood),
      ]),
    );
  }

  static int? _rating(int? value) =>
      value != null && value >= 1 && value <= 5 ? value : null;

  static T? _latestOn<T>(
    DateTime day,
    Iterable<T> entries,
    DateTime Function(T) dateOf,
  ) {
    final localDay = day.toLocal();
    T? latest;
    for (final entry in entries) {
      final date = dateOf(entry).toLocal();
      if (date.year == localDay.year &&
          date.month == localDay.month &&
          date.day == localDay.day &&
          (latest == null || date.isAfter(dateOf(latest)))) {
        latest = entry;
      }
    }
    return latest;
  }
}
