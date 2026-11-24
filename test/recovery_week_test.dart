import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/models/recovery_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Uses local Monday–Sunday bounds across a year boundary', () {
    final today = DateTime(2026, 1, 1);
    final start = DateTime(2025, 12, 29);
    final yesterday = DateTime(2025, 12, 31, 20);
    final outside = DateTime(2025, 12, 28, 23, 59, 59);
    final future = DateTime(2026, 1, 2);
    SleepEntry sleep(DateTime date, double hours) => SleepEntry(
      id: '$date',
      date: date,
      hours: hours,
      quality: null,
      notes: '',
    );
    final result = RecoveryWeek.fromRecords(
      selected: today,
      today: today,
      sleep: [
        sleep(start.toUtc(), 8),
        sleep(start, 6),
        sleep(yesterday, 9),
        sleep(today, double.nan),
        sleep(outside, 18),
        sleep(future, 16),
      ],
      wellness: [],
      mobility: [],
      notes: [],
    );
    expect(result.start, start);
    expect(result.end, DateTime(2026, 1, 4));
    expect(result.days(RecoveryWeekMetric.sleep), [
      7,
      null,
      9,
      null,
      null,
      null,
      null,
    ]);
    expect(result.value(RecoveryWeekMetric.sleep), 8);
    expect(result.measuredDays(RecoveryWeekMetric.sleep), 2);
    expect(result.count(RecoveryActivity.sleep), 3);
    expect(result.value(RecoveryWeekMetric.energy), isNull);
  });

  test('Keeps calendar day slots across the spring clock-change weekend', () {
    final sunday = DateTime(2026, 3, 8);
    final monday = RecoveryWeek.mondayOf(sunday);
    final nextMonday = RecoveryWeek.offsetDays(monday, 7);
    expect(monday, DateTime(2026, 3, 2));
    expect(nextMonday, DateTime(2026, 3, 9));
    final result = RecoveryWeek.fromRecords(
      selected: sunday,
      today: sunday,
      sleep: [],
      wellness: [
        WellnessEntry(
          id: 'sunday',
          date: sunday,
          energy: 6,
          soreness: 2,
          mood: null,
          hrv: 0,
          notes: '',
        ),
        WellnessEntry(
          id: 'next',
          date: nextMonday,
          energy: 4,
          soreness: 1,
          mood: 5,
          notes: '',
        ),
      ],
      mobility: [
        MobilityEntry(
          id: 'bad',
          date: sunday,
          activity: MobilityActivity.yoga,
          minutes: 0,
        ),
        MobilityEntry(
          id: 'valid',
          date: sunday,
          activity: MobilityActivity.yoga,
          minutes: 12,
        ),
        MobilityEntry(
          id: 'next',
          date: nextMonday,
          activity: MobilityActivity.yoga,
          minutes: 15,
        ),
      ],
      notes: [
        RecoveryNote(id: 'sunday', date: sunday, title: '', body: ''),
        RecoveryNote(id: 'next', date: nextMonday, title: '', body: ''),
      ],
    );
    expect(result.days(RecoveryWeekMetric.soreness), [
      null,
      null,
      null,
      null,
      null,
      null,
      2,
    ]);
    expect(result.value(RecoveryWeekMetric.energy), isNull);
    expect(result.value(RecoveryWeekMetric.hrv), isNull);
    expect(result.value(RecoveryWeekMetric.mobility), 12);
    expect(result.count(RecoveryActivity.wellness), 1);
    expect(result.count(RecoveryActivity.notes), 1);
    expect(result.count(RecoveryActivity.mobility), 1);
  });
}
