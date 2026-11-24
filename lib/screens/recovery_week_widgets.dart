import 'package:flutter/material.dart';

import '../data/collection_store.dart';
import '../models/health_models.dart';
import '../models/recovery_week.dart';
import '../theme.dart';

class RecoveryWeekRecords {
  const RecoveryWeekRecords(
    this.sleep,
    this.wellness,
    this.mobility,
    this.notes,
  );

  final CollectionStore<SleepEntry> sleep;
  final CollectionStore<WellnessEntry> wellness;
  final CollectionStore<MobilityEntry> mobility;
  final CollectionStore<RecoveryNote> notes;

  Listenable get changes =>
      Listenable.merge([sleep, wellness, mobility, notes]);

  String? status(RecoveryActivity activity) {
    final store = switch (activity) {
      RecoveryActivity.sleep => sleep,
      RecoveryActivity.wellness => wellness,
      RecoveryActivity.mobility => mobility,
      RecoveryActivity.notes => notes,
    };
    return store.loading
        ? 'Loading…'
        : store.error == null
        ? null
        : 'Unavailable';
  }

  RecoveryWeek week(DateTime selected, DateTime today) =>
      RecoveryWeek.fromRecords(
        selected: selected,
        today: today,
        sleep: status(RecoveryActivity.sleep) == null ? sleep.items : const [],
        wellness: status(RecoveryActivity.wellness) == null
            ? wellness.items
            : const [],
        mobility: status(RecoveryActivity.mobility) == null
            ? mobility.items
            : const [],
        notes: status(RecoveryActivity.notes) == null ? notes.items : const [],
      );
}

class RecoveryWeekTrend extends StatelessWidget {
  const RecoveryWeekTrend({
    super.key,
    required this.metric,
    required this.week,
    required this.color,
    this.status,
    this.hidden = false,
  });

  final RecoveryWeekMetric metric;
  final RecoveryWeek week;
  final Color color;
  final String? status;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final average = week.value(metric);
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
                hidden
                    ? 'Hidden'
                    : status ??
                          (average == null ? '—' : metric.format(average)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Avg ${metric.label}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              RecoveryWeekChart(
                metric: metric,
                week: hidden ? null : week,
                color: color,
                height: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecoveryWeekChart extends StatelessWidget {
  const RecoveryWeekChart({
    super.key,
    required this.metric,
    required this.week,
    required this.color,
    required this.height,
    this.previous,
  });

  final RecoveryWeekMetric metric;
  final RecoveryWeek? week;
  final Color color;
  final double height;
  final RecoveryWeek? previous;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final currentValues =
        week?.days(metric) ??
        const <double?>[null, null, null, null, null, null, null];
    final previousValues = previous?.days(metric);
    final maximum = [...currentValues, ...?previousValues]
        .whereType<double>()
        .fold<double>(1, (scale, value) => value > scale ? value : scale);
    final comparison = previousValues != null;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var day = 0; day < _days.length; day++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (comparison)
                        _bar(
                          previousValues[day],
                          maximum,
                          color.withValues(alpha: .35),
                          'Previous week ${_days[day]}',
                        ),
                      _bar(
                        currentValues[day],
                        maximum,
                        color,
                        comparison ? 'Selected week ${_days[day]}' : _days[day],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.black12),
        if (comparison)
          Row(
            children: [
              for (final label in _days)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _bar(double? value, double maximum, Color color, String day) =>
      Expanded(
        child: value == null
            ? const SizedBox.shrink()
            : Tooltip(
                message: '$day ${metric.label}: ${metric.format(value)}',
                child: Container(
                  height: height * value / maximum,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
              ),
      );
}
