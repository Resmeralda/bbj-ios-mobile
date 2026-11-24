import 'health_models.dart';

enum RecoveryActivity {
  sleep('Sleep logs'),
  wellness('Wellness check-ins'),
  mobility('Mobility activities'),
  notes('Recovery notes');

  const RecoveryActivity(this.label);
  final String label;
}

enum RecoveryWeekMetric {
  sleep('Sleep', RecoveryActivity.sleep),
  energy('Energy', RecoveryActivity.wellness),
  soreness('Soreness', RecoveryActivity.wellness),
  mood('Mood', RecoveryActivity.wellness),
  hrv('HRV', RecoveryActivity.wellness),
  mobility('Mobility duration', RecoveryActivity.mobility);

  const RecoveryWeekMetric(this.label, this.activity);
  final String label;
  final RecoveryActivity activity;

  String format(double value) => switch (this) {
    sleep => '${value.toStringAsFixed(1)} hr',
    energy || soreness || mood => '${value.toStringAsFixed(1)} / 5',
    hrv => '${value.round()} ms',
    mobility => '${value.round()} min',
  };
}

class RecoveryWeek {
  const RecoveryWeek._(this.start, this._series, this._counts);

  final DateTime start;
  final Map<RecoveryWeekMetric, List<double?>> _series;
  final Map<RecoveryActivity, int> _counts;

  DateTime get end => offsetDays(start, 6);

  static DateTime offsetDays(DateTime date, int days) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day + days);
  }

  static DateTime mondayOf(DateTime date) =>
      offsetDays(date, 1 - date.toLocal().weekday);

  List<double?> days(RecoveryWeekMetric metric) => _series[metric]!;

  int count(RecoveryActivity activity) => _counts[activity]!;

  int measuredDays(RecoveryWeekMetric metric) =>
      days(metric).whereType<double>().length;

  double? value(RecoveryWeekMetric metric) {
    final recorded = days(metric).whereType<double>();
    if (recorded.isEmpty) return null;
    final total = recorded.reduce((a, b) => a + b);
    return metric == RecoveryWeekMetric.mobility
        ? total
        : total / recorded.length;
  }

  factory RecoveryWeek.fromRecords({
    required DateTime selected,
    required DateTime today,
    required Iterable<SleepEntry> sleep,
    required Iterable<WellnessEntry> wellness,
    required Iterable<MobilityEntry> mobility,
    required Iterable<RecoveryNote> notes,
  }) {
    final start = mondayOf(selected);
    final endExclusive = offsetDays(start, 7);
    final tomorrow = offsetDays(today, 1);
    final samples = {
      for (final metric in RecoveryWeekMetric.values)
        metric: List.generate(7, (_) => <double>[]),
    };
    final counts = {
      for (final activity in RecoveryActivity.values) activity: 0,
    };

    int? dayIndex(DateTime date) {
      final local = date.toLocal();
      return local.isBefore(start) ||
              !local.isBefore(endExclusive) ||
              !local.isBefore(tomorrow)
          ? null
          : local.weekday - 1;
    }

    void count(RecoveryActivity activity) =>
        counts[activity] = counts[activity]! + 1;

    void addRating(RecoveryWeekMetric metric, int index, int? rating) {
      if (rating != null && rating >= 1 && rating <= 5) {
        samples[metric]![index].add(rating.toDouble());
      }
    }

    for (final entry in sleep) {
      final day = dayIndex(entry.date);
      if (day == null || !SleepEntry.validHours(entry.hours)) continue;
      samples[RecoveryWeekMetric.sleep]![day].add(entry.hours);
      count(RecoveryActivity.sleep);
    }
    for (final entry in wellness) {
      final day = dayIndex(entry.date);
      if (day == null) continue;
      count(RecoveryActivity.wellness);
      addRating(RecoveryWeekMetric.energy, day, entry.energy);
      addRating(RecoveryWeekMetric.soreness, day, entry.soreness);
      addRating(RecoveryWeekMetric.mood, day, entry.mood);
      final hrv = entry.hrv?.toDouble();
      if (WellnessEntry.validHrv(hrv)) {
        samples[RecoveryWeekMetric.hrv]![day].add(hrv!);
      }
    }
    for (final entry in mobility) {
      final day = dayIndex(entry.date);
      if (day == null || !MobilityEntry.validMinutes(entry.minutes)) continue;
      samples[RecoveryWeekMetric.mobility]![day].add(entry.minutes.toDouble());
      count(RecoveryActivity.mobility);
    }
    for (final entry in notes) {
      if (dayIndex(entry.date) != null) count(RecoveryActivity.notes);
    }

    return RecoveryWeek._(start, {
      for (final entry in samples.entries)
        entry.key: List<double?>.unmodifiable(
          entry.value.map((values) {
            if (values.isEmpty) return null;
            final total = values.reduce((a, b) => a + b);
            return entry.key == RecoveryWeekMetric.mobility
                ? total
                : total / values.length;
          }),
        ),
    }, counts);
  }
}
