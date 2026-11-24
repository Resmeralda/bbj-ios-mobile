import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/models/recovery_score.dart';
import 'package:bjj_app/models/recovery_settings.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 11, 24, 12);

SleepEntry _sleep(DateTime date, {double hours = 6, int? quality = 4}) =>
    SleepEntry(
      id: 'sleep',
      date: date,
      hours: hours,
      quality: quality,
      notes: '',
    );

WellnessEntry _wellness(
  DateTime date, {
  int? energy = 4,
  int? soreness = 2,
  int? mood = 3,
  int? hrv = 68,
}) => WellnessEntry(
  id: 'wellness',
  date: date,
  energy: energy,
  soreness: soreness,
  mood: mood,
  hrv: hrv,
  notes: '',
);

RecoveryAssessment _assess({
  required Iterable<SleepEntry> sleep,
  required Iterable<WellnessEntry> wellness,
  RecoverySettings? settings = const RecoverySettings(),
}) => RecoveryAssessment.forDay(
  day: _day,
  sleepEntries: sleep,
  wellnessEntries: wellness,
  settings: settings,
);

void main() {
  test(
    'Calculates weighted points, inverts soreness and rounds the total once',
    () {
      final assessment = _assess(
        sleep: [_sleep(_day)],
        wellness: [_wellness(_day)],
      );
      expect(assessment.components.map((part) => part.fraction), [
        .75,
        .75,
        .75,
        .5,
      ]);
      expect(assessment.components.map((part) => part.points), [
        18.75,
        18.75,
        18.75,
        12.5,
      ]);
      expect(assessment.score, 69);
      expect(assessment.rating, RecoveryRating.moderate);
      expect(assessment.sleepQuality, 4);
      expect(assessment.hrv, 68);

      final high = _assess(
        sleep: [_sleep(_day, hours: 10, quality: null)],
        wellness: [_wellness(_day, energy: 5, soreness: 1, mood: 5, hrv: null)],
      );
      expect(high.score, 100);
      expect(high.rating, RecoveryRating.high);
      expect(high.sleepQuality, isNull);
      expect(high.hrv, isNull);
    },
  );

  test('Uses exactly the approved inclusive rating boundaries', () {
    expect(RecoveryRating.forScore(0), RecoveryRating.low);
    expect(RecoveryRating.forScore(39), RecoveryRating.low);
    expect(RecoveryRating.forScore(40), RecoveryRating.moderate);
    expect(RecoveryRating.forScore(69), RecoveryRating.moderate);
    expect(RecoveryRating.forScore(70), RecoveryRating.high);
    expect(RecoveryRating.forScore(100), RecoveryRating.high);
  });

  test(
    'Selects the newest records on the local date, without mixing check-ins',
    () {
      final morning = DateTime(_day.year, _day.month, _day.day, 7);
      final yesterday = DateTime(_day.year, _day.month, _day.day - 1, 23);
      final tomorrow = DateTime(_day.year, _day.month, _day.day + 1);
      final assessment = _assess(
        sleep: [
          _sleep(morning.toUtc()),
          _sleep(yesterday),
          _sleep(tomorrow),
          _sleep(_day, hours: 7.5),
          _sleep(_day, hours: double.nan),
        ],
        wellness: [
          _wellness(_day, mood: null),
          _wellness(morning),
          _wellness(tomorrow),
        ],
      );
      expect(assessment.sleep!.hours, 7.5);
      expect(assessment.wellness!.date, _day);
      expect(assessment.components.map((part) => part.value), [
        7.5,
        4,
        2,
        null,
      ]);
      expect(assessment.score, isNull);
      expect(assessment.rating, isNull);
    },
  );

  test(
    'Malformed fields stay missing and supplemental values never affect points',
    () {
      final partial = WellnessEntry.fromMap('partial', {
        'date': _day.toIso8601String(),
        'energy': '5',
        'soreness': 1,
        'mood': 2.5,
        'hrv': double.infinity,
      });
      for (final key in ['energy', 'mood', 'hrv']) {
        expect(partial.toMap(), isNot(contains(key)));
      }
      expect(partial.energy, isNull);
      expect(partial.mood, isNull);
      expect(partial.hrv, isNull);
      expect(
        () => WellnessEntry.fromMap('bad-date', {}),
        throwsFormatException,
      );
      final sleep = SleepEntry.fromMap('sleep', {
        'date': _day.toIso8601String(),
        'hours': 6,
      });
      final assessment = _assess(sleep: [sleep], wellness: [partial]);
      expect(assessment.score, isNull);
      expect(assessment.sleepQuality, isNull);
      expect(assessment.components[2].points, 25);
      final noGoal = _assess(
        sleep: [sleep],
        wellness: [_wellness(_day)],
        settings: null,
      );
      expect(noGoal.components.first.value, 6);
      expect(noGoal.components.first.points, isNull);
      expect(noGoal.score, isNull);
      final controls = [
        _assess(
          sleep: [_sleep(_day, quality: 1)],
          wellness: [_wellness(_day, hrv: 40)],
        ),
        _assess(
          sleep: [_sleep(_day, quality: 5)],
          wellness: [_wellness(_day, hrv: 80)],
        ),
      ];
      expect(controls.map((result) => result.score), [69, 69]);
    },
  );
}
