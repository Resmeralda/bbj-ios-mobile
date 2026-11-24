import 'package:flutter/material.dart';

import '../data/recovery_settings_store.dart';
import '../data/stores.dart';
import '../models/recovery_week.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'recovery_week_widgets.dart';

class RecoveryWeekScreen extends StatefulWidget {
  const RecoveryWeekScreen({
    super.key,
    this.records,
    this.settings,
    this.clock,
  });

  final RecoveryWeekRecords? records;
  final RecoverySettingsStore? settings;
  final DateTime Function()? clock;

  @override
  State<RecoveryWeekScreen> createState() => _RecoveryWeekScreenState();
}

class _RecoveryWeekScreenState extends State<RecoveryWeekScreen> {
  static final _firstDate = DateTime(2020);
  DateTime? _selection;

  Future<void> _pickDate(DateTime selected, DateTime today) async {
    final date = await showDatePicker(
      context: context,
      initialDate: selected.isBefore(_firstDate) ? _firstDate : selected,
      firstDate: _firstDate,
      lastDate: today,
    );
    if (date != null && mounted) setState(() => _selection = date);
  }

  String _range(BuildContext context, RecoveryWeek week) {
    final dates = MaterialLocalizations.of(context);
    return '${dates.formatShortDate(week.start)} – ${dates.formatShortDate(week.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final records =
        widget.records ??
        RecoveryWeekRecords(
          sleepStore,
          wellnessStore,
          mobilityStore,
          noteStore,
        );
    final settings = widget.settings ?? recoverySettingsStore;
    return ListenableBuilder(
      listenable: Listenable.merge([records.changes, settings]),
      builder: (context, _) {
        final today = DateUtils.dateOnly(
          (widget.clock?.call() ?? DateTime.now()).toLocal(),
        );
        final selected = _selection ?? today;
        final current = records.week(selected, today);
        final previous = records.week(
          RecoveryWeek.offsetDays(current.start, -7),
          today,
        );
        final isCurrent = current.start == RecoveryWeek.mondayOf(today);
        final currentLabel = isCurrent ? 'This week' : 'Selected week';
        final previousLabel = isCurrent ? 'Last week' : 'Previous week';
        final canGoBack = !previous.end.isBefore(_firstDate);
        final noRecords = RecoveryActivity.values.every(
          (activity) =>
              records.status(activity) == null &&
              current.count(activity) == 0 &&
              previous.count(activity) == 0,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Weekly Recovery Summary'),
            backgroundColor: AppColors.recovery,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Choose recovery week',
                icon: const Icon(Icons.calendar_month),
                onPressed: () => _pickDate(selected, today),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous recovery week',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: canGoBack
                            ? () => setState(() => _selection = previous.start)
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              currentLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _range(context, current),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              previousLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _range(context, previous),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next recovery week',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: isCurrent
                            ? null
                            : () => setState(
                                () => _selection = RecoveryWeek.offsetDays(
                                  current.start,
                                  7,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (noRecords)
                  const AppCard(
                    child: Text(
                      'No recovery activities logged in either week.',
                    ),
                  ),
                const SectionHeader('Measurements'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Averages use only days with recorded measurements. Mobility shows total minutes.',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _Legend(
                            label: currentLabel,
                            color: AppColors.recovery,
                          ),
                          _Legend(
                            label: previousLabel,
                            color: AppColors.recovery.withValues(alpha: .35),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                for (final metric in RecoveryWeekMetric.values)
                  if (metric != RecoveryWeekMetric.hrv ||
                      settings.settings?.showHrv != false)
                    _Measurement(
                      metric: metric,
                      current: current,
                      previous: previous,
                      currentLabel: currentLabel,
                      previousLabel: previousLabel,
                      status: records.status(metric.activity),
                    ),
                const SectionHeader('Activity totals'),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(flex: 2, child: Text('Activity')),
                          Expanded(
                            child: Text(
                              currentLabel,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              previousLabel,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      for (final activity in RecoveryActivity.values)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(activity.label)),
                              Expanded(
                                child: Text(
                                  records.status(activity) ??
                                      '${current.count(activity)}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  records.status(activity) ??
                                      '${previous.count(activity)}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.square, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

class _Measurement extends StatelessWidget {
  const _Measurement({
    required this.metric,
    required this.current,
    required this.previous,
    required this.currentLabel,
    required this.previousLabel,
    required this.status,
  });

  final RecoveryWeekMetric metric;
  final RecoveryWeek current;
  final RecoveryWeek previous;
  final String currentLabel;
  final String previousLabel;
  final String? status;

  Widget _value(String label, RecoveryWeek week) {
    final value = week.value(metric);
    final days = week.measuredDays(metric);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Text(
            status ?? (value == null ? '—' : metric.format(value)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (status == null)
            Text(
              days == 0
                  ? 'No measurements'
                  : '$days recorded ${days == 1 ? 'day' : 'days'}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(metric.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _value(currentLabel, current),
            _value(previousLabel, previous),
          ],
        ),
        const SizedBox(height: 8),
        RecoveryWeekChart(
          metric: metric,
          week: current,
          previous: previous,
          color: AppColors.recovery,
          height: 56,
        ),
      ],
    ),
  );
}
