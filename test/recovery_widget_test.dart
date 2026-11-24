import 'package:bjj_app/data/collection_store.dart';
import 'package:bjj_app/data/recovery_settings_store.dart';
import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/models/recovery_settings.dart';
import 'package:bjj_app/models/training_session.dart' show formatDate;
import 'package:bjj_app/screens/recovery_details_screen.dart';
import 'package:bjj_app/screens/recovery_screen.dart';
import 'package:bjj_app/screens/recovery_score_widgets.dart';
import 'package:bjj_app/screens/recovery_settings_screen.dart';
import 'package:bjj_app/screens/recovery_week_screen.dart';
import 'package:bjj_app/screens/recovery_week_widgets.dart';
import 'package:bjj_app/widgets/common.dart';
import 'package:bjj_app/widgets/form_helpers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _uid = 'recovery-test-user';

CollectionStore<T> _boundStore<T>(
  FakeFirebaseFirestore firestore,
  String path,
  T Function(String, Map<String, dynamic>) fromMap,
  Map<String, dynamic> Function(T) toMap,
  String Function(T) idOf,
  DateTime Function(T) dateOf,
) {
  final store = CollectionStore<T>(
    path: path,
    fromMap: fromMap,
    toMap: toMap,
    idOf: idOf,
    compare: (a, b) => dateOf(b).compareTo(dateOf(a)),
    firestore: firestore,
  )..bind(_uid);
  addTearDown(store.dispose);
  return store;
}

Future<FakeFirebaseFirestore> _openRecovery(
  WidgetTester tester, {
  FakeFirebaseFirestore? database,
  DateTime Function()? clock,
}) async {
  final firestore = database ?? FakeFirebaseFirestore();
  final settings = RecoverySettingsStore(firestore: firestore);
  addTearDown(settings.dispose);
  await settings.bind(_uid);
  final recovery = RecoveryScreen(
    settings: settings,
    clock: clock,
    sleep: _boundStore(
      firestore,
      'sleep',
      SleepEntry.fromMap,
      (e) => e.toMap(),
      (e) => e.id,
      (e) => e.date,
    ),
    wellness: _boundStore(
      firestore,
      'wellness',
      WellnessEntry.fromMap,
      (e) => e.toMap(),
      (e) => e.id,
      (e) => e.date,
    ),
    notes: _boundStore(
      firestore,
      'recovery_notes',
      RecoveryNote.fromMap,
      (e) => e.toMap(),
      (e) => e.id,
      (e) => e.date,
    ),
    mobility: _boundStore(
      firestore,
      'mobility',
      MobilityEntry.fromMap,
      (e) => e.toMap(),
      (e) => e.id,
      (e) => e.date,
    ),
    habits: _boundStore(
      firestore,
      'recovery_habits',
      RecoveryHabitDay.fromMap,
      (e) => e.toMap(),
      (e) => e.id,
      (e) => DateTime.parse(e.id),
    ),
  );
  final router = GoRouter(
    initialLocation: '/recovery',
    routes: [
      GoRoute(
        path: '/recovery',
        builder: (_, _) => recovery,
        routes: [
          GoRoute(
            path: 'details',
            builder: (_, _) => RecoveryDetailsScreen(
              sleep: recovery.sleep,
              wellness: recovery.wellness,
              settings: settings,
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, _) => RecoverySettingsScreen(store: settings),
          ),
          GoRoute(
            path: 'weekly',
            builder: (_, _) => RecoveryWeekScreen(
              records: RecoveryWeekRecords(
                recovery.sleep!,
                recovery.wellness!,
                recovery.mobility!,
                recovery.notes!,
              ),
              settings: settings,
              clock: clock,
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return firestore;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.descendant(
  of: find.byKey(const ValueKey('Recovery tabs')),
  matching: find.widgetWithText(InkWell, label),
);

Finder _habit(String label) => find.widgetWithText(CheckboxListTile, label);

bool? _checked(WidgetTester tester, String label) =>
    tester.widget<CheckboxListTile>(_habit(label)).value;

Finder _recentNotesLink() => find.descendant(
  of: find.widgetWithText(SectionHeader, 'Recent Notes'),
  matching: find.text('View All'),
);

Finder _weeklyLink() => find.descendant(
  of: find.widgetWithText(SectionHeader, 'This Week'),
  matching: find.text('View All'),
);

Finder _goalInput() => find.widgetWithText(TextFormField, 'Sleep goal (hours)');

void _expectScore(WidgetTester tester, int? score, Color color) {
  final ring = tester.widget<CircularProgressIndicator>(
    find.byType(CircularProgressIndicator),
  );
  expect(ring.value, (score ?? 0) / 100);
  expect(ring.color, color);
  expect(
    tester
        .widget<ExcludeSemantics>(
          find
              .ancestor(
                of: find.byType(CircularProgressIndicator),
                matching: find.byType(ExcludeSemantics),
              )
              .first,
        )
        .excluding,
    score == null,
  );
}

Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  for (final (shortcut, save, path) in [
    ('Log Sleep', 'Save', 'sleep'),
    ('Log Wellness', 'Save', 'wellness'),
    ('Add Note', 'Save Note', 'recovery_notes'),
  ]) {
    testWidgets('$shortcut rejects a draft from the previous account', (
      tester,
    ) async {
      await _tallViewport(tester);
      final firestore = await _openRecovery(tester);
      final screen = tester.widget<RecoveryScreen>(find.byType(RecoveryScreen));
      await _tap(tester, find.text(shortcut));
      await tester.enterText(find.byType(TextFormField).first, '7');
      if (path == 'recovery_notes') {
        await tester.enterText(
          find.byType(TextFormField).last,
          'Private draft',
        );
      }
      screen.sleep!.bind('other');
      screen.wellness!.bind('other');
      screen.notes!.bind('other');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, save));
      expect(find.text(staleAccountMessage), findsOneWidget);
      expect(
        (await firestore.collection('users/other/$path').get()).docs,
        isEmpty,
      );
      expect(
        (await firestore.collection('users/$_uid/$path').get()).docs,
        isEmpty,
      );
    });
  }

  testWidgets('Recovery checklist cannot toggle wind-down after rebinding', (
    tester,
  ) async {
    await _tallViewport(tester);
    final firestore = await _openRecovery(tester);
    final screen = tester.widget<RecoveryScreen>(find.byType(RecoveryScreen));
    await _tap(tester, find.text('Recovery Habits'));
    expect(_habit('Wind-down'), findsOneWidget);
    screen.habits!.bind('other');
    await tester.pumpAndSettle();
    expect(_habit('Wind-down'), findsNothing);
    expect(find.text(staleAccountMessage), findsOneWidget);
    expect(
      (await firestore.collection('users/other/recovery_habits').get()).docs,
      isEmpty,
    );
  });

  testWidgets('Weekly calendar stays within range for the first partial week', (
    tester,
  ) async {
    await _tallViewport(tester);
    await _openRecovery(tester, clock: () => DateTime(2020, 1, 6));
    await _tap(tester, _weeklyLink());
    await _tap(tester, find.byTooltip('Previous recovery week'));
    expect(find.textContaining('Dec 30, 2019'), findsOneWidget);
    final previous = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Previous recovery week',
      ),
    );
    expect(previous.onPressed, isNull);
    await _tap(tester, find.byTooltip('Choose recovery week'));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(find.textContaining('Dec 30, 2019'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Overview and weekly summary compare actual records and update live',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateTime(2026, 11, 24);
      final firestore = await _openRecovery(tester, clock: () => today);
      final user = firestore.collection('users').doc(_uid);
      final sleep = user.collection('sleep');
      final monday = DateTime(2026, 11, 23).toIso8601String();
      final tuesday = today.toIso8601String();
      final lastMonday = DateTime(2026, 11, 16).toIso8601String();
      final future = DateTime(2026, 11, 25).toIso8601String();
      await sleep.doc('mon-a').set({'date': monday, 'hours': 6});
      await sleep.doc('mon-b').set({'date': monday, 'hours': 10});
      await sleep.doc('tue').set({'date': tuesday, 'hours': 4});
      await sleep.doc('last').set({'date': lastMonday, 'hours': 7});
      await sleep.doc('future').set({'date': future, 'hours': 12});
      final wellness = user.collection('wellness');
      await wellness.doc('mon-a').set({
        'date': monday,
        'energy': 1,
        'soreness': 2,
        'mood': 2,
        'hrv': 60,
      });
      await wellness.doc('mon-b').set({
        'date': monday,
        'energy': 5,
        'soreness': 4,
        'mood': 4,
      });
      await wellness.doc('tue').set({
        'date': tuesday,
        'energy': 5,
        'mood': 5,
        'hrv': 80,
      });
      await wellness.doc('last').set({
        'date': lastMonday,
        'energy': 2,
        'soreness': 1,
        'mood': 3,
        'hrv': 65,
      });
      final mobility = user.collection('mobility');
      for (final (id, date, minutes) in [
        ('mon-a', monday, 10),
        ('mon-b', monday, 15),
        ('last', lastMonday, 18),
      ]) {
        await mobility.doc(id).set({
          'date': date,
          'activity': 'yoga',
          'minutes': minutes,
        });
      }
      await user.collection('recovery_notes').doc('note').set({
        'date': monday,
        'title': 'Actual note',
      });
      await tester.pumpAndSettle();
      final overview = find.byType(RecoveryWeekTrend);
      expect(overview, findsNWidgets(4));
      for (final value in ['6.0 hr', '4.0 / 5', '3.0 / 5', '70 ms']) {
        expect(
          find.descendant(of: overview, matching: find.text(value)),
          findsOneWidget,
        );
      }
      expect(find.byTooltip('Mon Sleep: 8.0 hr'), findsOneWidget);
      expect(find.byTooltip('Wed Sleep: 12.0 hr'), findsNothing);
      await _tap(tester, _weeklyLink());
      expect(find.text('Weekly Recovery Summary'), findsOneWidget);
      expect(find.text('This week'), findsWidgets);
      expect(find.text('Last week'), findsWidgets);
      expect(find.textContaining('Nov 23'), findsOneWidget);
      expect(find.textContaining('Nov 16'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('2 recorded days'), findsWidgets);
      expect(find.text('1 recorded day'), findsWidgets);
      expect(find.byTooltip('Selected week Mon Sleep: 8.0 hr'), findsOneWidget);
      expect(find.byTooltip('Previous week Mon Sleep: 7.0 hr'), findsOneWidget);
      expect(
        find.byTooltip('Selected week Tue Soreness: 0.0 / 5'),
        findsNothing,
      );
      expect(find.byTooltip('Selected week Wed Sleep: 12.0 hr'), findsNothing);
      expect(find.byTooltip('Selected week Tue Mood: 5.0 / 5'), findsOneWidget);
      final sleepTotals = find.widgetWithText(Row, 'Sleep logs');
      expect(
        find.descendant(of: sleepTotals, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sleepTotals, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Recovery notes'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Next recovery week',
              ),
            )
            .onPressed,
        isNull,
      );

      await sleep.doc('tue').update({'hours': 8});
      await tester.pumpAndSettle();
      expect(find.byTooltip('Selected week Tue Sleep: 8.0 hr'), findsOneWidget);
      await mobility.doc('mon-a').delete();
      await tester.pumpAndSettle();
      expect(find.text('25 min'), findsNothing);
      expect(find.text('15 min'), findsOneWidget);

      await _tap(tester, find.byTooltip('Previous recovery week'));
      expect(find.text('Selected week'), findsWidgets);
      expect(find.byTooltip('Selected week Mon Sleep: 7.0 hr'), findsOneWidget);
      await _tap(tester, find.byTooltip('Next recovery week'));
      expect(find.text('Last week'), findsWidgets);
      await _tap(tester, find.byTooltip('Choose recovery week'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await _tap(tester, find.text('19'));
      await _tap(tester, find.text('OK'));
      expect(find.byTooltip('Selected week Mon Sleep: 7.0 hr'), findsOneWidget);
      expect(find.textContaining('Nov 9'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      expect(find.byTooltip('Tue Sleep: 8.0 hr'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Weekly summary handles empty weeks and hides HRV when disabled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateTime(2026, 11, 24);
      final firestore = await _openRecovery(tester, clock: () => today);
      await _tap(tester, _weeklyLink());
      expect(
        find.text('No recovery activities logged in either week.'),
        findsOneWidget,
      );
      expect(find.text('No measurements'), findsWidgets);
      expect(find.text('0.0 hr'), findsNothing);
      await _tap(tester, find.byType(BackButton));

      final screen = tester.widget<RecoveryScreen>(find.byType(RecoveryScreen));
      final settings = screen.settings!;
      await settings.save(
        const RecoverySettings(showHrv: false),
        account: settings.account,
      );
      await firestore.doc('users/$_uid/wellness/hrv').set({
        'date': today.toIso8601String(),
        'energy': 4,
        'hrv': 72,
      });
      await tester.pumpAndSettle();
      expect(find.text('Hidden'), findsOneWidget);
      expect(find.byTooltip('Tue HRV: 72 ms'), findsNothing);
      await _tap(tester, _weeklyLink());
      expect(find.text('HRV'), findsNothing);
      expect(
        find.byTooltip('Selected week Tue Energy: 4.0 / 5'),
        findsOneWidget,
      );
      expect(
        find.text('No recovery activities logged in either week.'),
        findsNothing,
      );
      screen.wellness!.bind('other-athlete');
      await tester.pumpAndSettle();
      expect(
        find.text('No recovery activities logged in either week.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Selected week Tue Energy: 4.0 / 5'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Overview shortcuts have equal bounds and aligned icons', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    await _openRecovery(tester);
    const labels = [
      'Log Sleep',
      'Log Wellness',
      'Mobility / Stretching',
      'Add Note',
    ];
    expect(
      tester.getSize(find.text(labels[2])).height,
      closeTo(2 * tester.getSize(find.text(labels.last)).height, 1),
    );

    for (final width in [600.0, 320.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      await tester.pumpAndSettle();
      final tiles = [
        for (final label in labels) find.widgetWithText(QuickTile, label),
      ];
      final bounds = [
        for (final tile in tiles)
          tester.getRect(
            find.descendant(of: tile, matching: find.byType(Material)),
          ),
      ];
      final icons = [
        for (final tile in tiles)
          tester.getCenter(
            find.descendant(of: tile, matching: find.byType(Icon)),
          ),
      ];
      for (var i = 0; i < bounds.length; i++) {
        expect(bounds[i].size, bounds.first.size);
        expect(bounds[i].top, bounds.first.top);
        expect(icons[i].dx, closeTo(bounds[i].center.dx, .01));
        expect(icons[i].dy, icons.first.dy);
        if (i > 0) {
          expect(bounds[i].left - bounds[i - 1].right, closeTo(8, .01));
        }
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Mobility ignores invalid records and discards a stale account draft',
    (tester) async {
      await _tallViewport(tester);
      final firestore = await _openRecovery(tester);
      await firestore.doc('users/$_uid/mobility/invalid').set({
        'date': DateTime.now().toIso8601String(),
        'activity': 'unknown',
        'minutes': -1,
      });
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 completed'), findsOneWidget);
      await _tap(tester, _tab('Mobility'));
      expect(find.text('No mobility activities yet.'), findsOneWidget);
      await _tap(tester, find.text('Log Mobility'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duration (minutes)'),
        '12',
      );
      final screen = tester.widget<RecoveryScreen>(
        find.byType(RecoveryScreen, skipOffstage: false),
      );
      screen.mobility!.bind('other-athlete');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('Log mobility'), findsNothing);
      expect(
        (await firestore.collection('users/other-athlete/mobility').get()).docs,
        isEmpty,
      );
      expect(
        (await firestore.collection('users/$_uid/mobility').get())
            .docs
            .single
            .id,
        'invalid',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'All five Recovery tabs share one scrollable row on a narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openRecovery(tester);
      final rows = [
        for (final label in [
          'Overview',
          'Sleep',
          'Wellness',
          'Notes',
          'Mobility',
        ])
          tester.getTopLeft(_tab(label)).dy,
      ];
      expect(rows.toSet(), hasLength(1));
      final strip = find.descendant(
        of: find.byKey(const ValueKey('Recovery tabs')),
        matching: find.byType(SingleChildScrollView),
      );
      expect(strip, findsOneWidget);
      await tester.drag(strip, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(_tab('Mobility').hitTestable(), findsOneWidget);
      await _tap(tester, _tab('Mobility'));
      expect(find.text('No mobility activities yet.'), findsOneWidget);
      await _tap(tester, find.text('Log Mobility'));
      expect(find.text('Log mobility'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Overview logs mobility and the tab edits and deletes the same record',
    (tester) async {
      await _tallViewport(tester);
      final firestore = await _openRecovery(tester);
      final collection = firestore.collection('users/$_uid/mobility');
      await _tap(tester, find.text('Mobility / Stretching'));
      expect(find.text('Log mobility'), findsOneWidget);
      await _tap(
        tester,
        find.byType(DropdownButtonFormField<MobilityActivity>),
      );
      for (final label in [
        'Stretching',
        'Mobility exercises',
        'Foam rolling',
        'Yoga',
        'Other',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      await _tap(tester, find.text('Foam rolling').last);
      final minutes = find.widgetWithText(TextFormField, 'Duration (minutes)');
      final save = find.widgetWithText(FilledButton, 'Save');
      for (final invalid in ['0', '15.5']) {
        await tester.enterText(minutes, invalid);
        await _tap(tester, save);
        expect(
          find.text('Enter a positive whole number of minutes'),
          findsOneWidget,
        );
        expect((await collection.get()).docs, isEmpty);
      }
      await tester.enterText(minutes, '15');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Body area (optional)'),
        ' Hips ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        ' Post-training ',
      );
      await _tap(tester, save);
      expect(find.text('1 of 5 completed'), findsOneWidget);
      final recorded = (await collection.get()).docs.single;
      expect(recorded.data(), containsPair('minutes', 15));
      expect(recorded.data(), containsPair('activity', 'foamRolling'));
      expect(recorded.data(), containsPair('bodyArea', 'Hips'));
      expect(recorded.data(), containsPair('notes', 'Post-training'));

      await _tap(tester, _tab('Mobility'));
      expect(find.text('Foam rolling • 15 min'), findsOneWidget);
      expect(find.textContaining('Hips'), findsOneWidget);
      expect(find.text('Post-training'), findsOneWidget);
      await _tap(tester, find.text('Foam rolling • 15 min'));
      expect(find.text('Edit mobility'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      tester.widget<DateField>(find.byType(DateField)).onChanged(yesterday);
      await tester.enterText(minutes, '20');
      await _tap(tester, save);
      expect(find.text('Foam rolling • 20 min'), findsOneWidget);
      final edited = (await collection.get()).docs.single;
      expect(edited.id, recorded.id);
      expect(edited.data(), containsPair('date', yesterday.toIso8601String()));
      await _tap(tester, _tab('Overview'));
      expect(find.text('0 of 5 completed'), findsOneWidget);

      await _tap(tester, _tab('Mobility'));
      await _tap(tester, find.byIcon(Icons.delete_outline));
      expect(find.text('Delete mobility activity?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect((await collection.get()).docs.single.id, recorded.id);
      await _tap(tester, find.byIcon(Icons.delete_outline));
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect((await collection.get()).docs, isEmpty);
      expect(find.text('No mobility activities yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily habits track records and wind-down across local midnight',
    (tester) async {
      await _tallViewport(tester);
      var now = DateTime(2026, 11, 24, 23, 59, 59);
      final firestore = await _openRecovery(tester, clock: () => now);
      final user = firestore.collection('users').doc(_uid);
      final date = now.toIso8601String();
      final sleep = user.collection('sleep').doc('night');
      final wellness = user.collection('wellness').doc('check-in');
      final mobility = user.collection('mobility').doc('activity');
      final note = user.collection('recovery_notes').doc('note');
      final yesterday = user.collection('recovery_habits').doc('2026-11-24');
      final tomorrow = user.collection('recovery_habits').doc('2026-11-25');
      await _tap(tester, find.text('Recovery Habits'));
      expect(find.text('Daily Recovery Habits'), findsOneWidget);
      expect(find.text('2026-11-24'), findsOneWidget);
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where((tile) => tile.value == true),
        isEmpty,
      );

      await sleep.set({'date': date, 'hours': 7});
      await wellness.set({'date': date, 'energy': 4});
      await mobility.set({'date': date, 'activity': 'yoga', 'minutes': 15});
      await note.set({'date': date, 'title': 'After class'});
      await tester.pumpAndSettle();
      for (final label in [
        'Log last night’s sleep',
        'Log wellness',
        'Log mobility',
        'Add a recovery note',
      ]) {
        expect(_checked(tester, label), isTrue);
        expect(
          tester.widget<CheckboxListTile>(_habit(label)).onChanged,
          isNull,
        );
      }
      expect(find.text('4 of 5 completed'), findsOneWidget);
      expect(
        tester
            .widgetList<ProgressBar>(find.byType(ProgressBar))
            .map((bar) => bar.value),
        contains(.8),
      );
      await _tap(tester, _habit('Wind-down'));
      expect((await yesterday.get()).data(), {'windDown': true});
      expect(find.text('5 of 5 completed'), findsOneWidget);
      await _tap(tester, _habit('Wind-down'));
      expect((await yesterday.get()).data(), {'windDown': false});
      expect(_checked(tester, 'Wind-down'), isFalse);
      await _tap(tester, _habit('Wind-down'));

      await wellness.delete();
      await note.update({'date': DateTime(2026, 11, 23).toIso8601String()});
      await tester.pumpAndSettle();
      expect(_checked(tester, 'Log wellness'), isFalse);
      expect(_checked(tester, 'Add a recovery note'), isFalse);
      expect(find.text('3 of 5 completed'), findsOneWidget);

      now = DateTime(2026, 11, 25);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-25'), findsOneWidget);
      expect(find.text('0 of 5 completed'), findsOneWidget);
      expect(_checked(tester, 'Wind-down'), isFalse);
      expect((await yesterday.get()).data(), {'windDown': true});
      expect((await tomorrow.get()).exists, isFalse);
      await _tap(tester, _habit('Wind-down'));
      expect((await tomorrow.get()).data(), {'windDown': true});
      final screen = tester.widget<RecoveryScreen>(
        find.byType(RecoveryScreen, skipOffstage: false),
      );
      screen.habits!.bind('another-athlete');
      await tester.pumpAndSettle();
      expect(_habit('Wind-down'), findsNothing);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Recovery Habits'));
      expect(_checked(tester, 'Wind-down'), isFalse);
      expect(
        (await firestore
                .doc('users/another-athlete/recovery_habits/2026-11-25')
                .get())
            .exists,
        isFalse,
      );
      screen.habits!.bind(_uid);
      await tester.pumpAndSettle();
      expect(_habit('Wind-down'), findsNothing);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Recovery Habits'));
      expect(_checked(tester, 'Wind-down'), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = DateTime(2026, 11, 26, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('2026-11-26'), findsOneWidget);
      expect(_checked(tester, 'Wind-down'), isFalse);
      expect((await tomorrow.get()).data(), {'windDown': true});
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Recovery Details explains factors and rating bands on a narrow screen',
    (tester) async {
      await _tallViewport(tester);
      await _openRecovery(tester);
      await _tap(tester, find.text('View Details'));
      await tester.binding.setSurfaceSize(const Size(320, 780));
      await tester.pumpAndSettle();
      final intro = find.text(
        'Four equally weighted factors contribute to your score.',
      );
      await tester.scrollUntilVisible(intro, 200);
      final card = find.ancestor(of: intro, matching: find.byType(AppCard));
      Finder inGuide(Finder matching) =>
          find.descendant(of: card, matching: matching);
      expect(inGuide(find.text('25 points')), findsNWidgets(4));
      for (final (label, icon) in [
        ('Sleep', Icons.nightlight_round),
        ('Energy', Icons.bolt),
        ('Soreness', Icons.accessibility_new),
        ('Mood', Icons.emoji_emotions),
      ]) {
        expect(inGuide(find.text(label)), findsOneWidget);
        expect(inGuide(find.byIcon(icon)), findsOneWidget);
      }
      for (final (label, range, color) in [
        ('Low', '0–39', Colors.red),
        ('Moderate', '40–69', Colors.amber),
        ('High', '70–100', Colors.green),
      ]) {
        expect(inGuide(find.text(label)), findsOneWidget);
        expect(inGuide(find.text(range)), findsOneWidget);
        expect(
          inGuide(
            find.byWidgetPredicate(
              (widget) => widget is Container && widget.color == color,
            ),
          ),
          findsOneWidget,
        );
      }
      expect(
        inGuide(
          find.text(
            'Higher energy, better sleep, positive mood, and lower soreness improve your score.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        inGuide(
          find.text(
            'This score is a wellness estimate, not a medical assessment.',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Overview and Details update partial metrics, score and rating', (
    tester,
  ) async {
    await _tallViewport(tester);
    final firestore = await _openRecovery(tester);
    final now = DateTime.now();
    final date = now.toIso8601String();
    final sleep = firestore.doc('users/$_uid/sleep/night');
    final wellness = firestore.doc('users/$_uid/wellness/check-in');
    await wellness.set({'date': date, 'energy': 4, 'soreness': 2, 'hrv': 68});
    await tester.pumpAndSettle();
    _expectScore(tester, null, Colors.grey);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    final scoreCard = find.ancestor(
      of: find.byType(RecoveryScoreRing),
      matching: find.byType(AppCard),
    );
    Finder scoreValue(String value) =>
        find.descendant(of: scoreCard, matching: find.text(value));
    expect(scoreValue('68 ms'), findsOneWidget);

    await sleep.set({'date': date, 'hours': 7.5, 'quality': 5});
    await tester.pumpAndSettle();
    expect(scoreValue('7.5 hr'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    _expectScore(tester, null, Colors.grey);

    await _tap(tester, find.text('View Details'));
    expect(find.text('Recovery Details'), findsOneWidget);
    expect(find.text('7.5 hr / 8 hr'), findsOneWidget);
    expect(find.text('94% • 23.4 / 25 points'), findsOneWidget);
    expect(find.text('75% • 18.8 / 25 points'), findsNWidgets(2));
    expect(find.text('Not logged'), findsOneWidget);
    expect(find.text('Recorded ${formatDate(now)}'), findsNWidgets(3));
    expect(
      find.text('Sleep quality: 5 / 5 • ${formatDate(now)}'),
      findsOneWidget,
    );
    expect(find.text('HRV: 68 ms • ${formatDate(now)}'), findsOneWidget);
    expect(
      tester
          .widgetList<ProgressBar>(find.byType(ProgressBar))
          .map((bar) => bar.value),
      [.9375, .75, .75],
    );

    await wellness.update({'mood': 3});
    await tester.pumpAndSettle();
    _expectScore(tester, 73, Colors.green);
    expect(
      find.descendant(
        of: find.byType(RecoveryScoreRing),
        matching: find.text('High'),
      ),
      findsOneWidget,
    );
    expect(find.text('50% • 12.5 / 25 points'), findsOneWidget);
    expect(find.text('Recorded ${formatDate(now)}'), findsNWidgets(4));
    await _tap(tester, find.byType(BackButton));
    _expectScore(tester, 73, Colors.green);

    await sleep.update({'hours': 6});
    await tester.pumpAndSettle();
    _expectScore(tester, 69, Colors.amber);
    expect(find.text('Moderate'), findsWidgets);
    await wellness.update({'energy': 1, 'soreness': 5, 'mood': 1});
    await tester.pumpAndSettle();
    _expectScore(tester, 19, Colors.red);
    expect(find.text('Low'), findsWidgets);

    await _tap(tester, find.text('View Details'));
    _expectScore(tester, 19, Colors.red);
    await wellness.delete();
    await tester.pumpAndSettle();
    _expectScore(tester, null, Colors.grey);
    expect(find.text('6.0 hr / 8 hr'), findsOneWidget);
    expect(find.text('Not logged'), findsNWidgets(3));
    expect(find.textContaining('HRV:'), findsNothing);
    await sleep.delete();
    await tester.pumpAndSettle();
    expect(find.text('Not logged'), findsNWidgets(4));
    expect(find.byType(ProgressBar), findsNothing);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('No sleep logged for last night'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Editing notes on a partial wellness record keeps ratings missing',
    (tester) async {
      await _tallViewport(tester);
      final firestore = await _openRecovery(tester);
      final record = firestore.doc('users/$_uid/wellness/partial');
      await record.set({'date': DateTime.now().toIso8601String(), 'energy': 4});
      await tester.pumpAndSettle();
      await _tap(tester, _tab('Wellness'));
      expect(find.text('Energy 4  •  Soreness —  •  Mood —'), findsOneWidget);
      await _tap(tester, find.byType(EntryTile));
      final controls = tester.widgetList<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(controls.map((control) => control.selected), [
        {4},
        <int>{},
        <int>{},
      ]);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        'Updated note',
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
      final data = (await record.get()).data()!;
      expect(data['notes'], 'Updated note');
      expect(data['energy'], 4);
      expect(data.containsKey('soreness'), isFalse);
      expect(data.containsKey('mood'), isFalse);
      await _tap(tester, _tab('Overview'));
      _expectScore(tester, null, Colors.grey);
      expect(find.text('4 / 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Empty Overview keeps the cards and hides sample activity', (
    tester,
  ) async {
    await _tallViewport(tester);
    await _openRecovery(tester);

    expect(find.text('No sleep logged for last night'), findsOneWidget);
    expect(find.text('Goal: 8 hr'), findsOneWidget);
    expect(find.text('No recovery notes yet.'), findsOneWidget);
    expect(find.text('0 of 5 completed'), findsOneWidget);
    expect(find.text('Avg Sleep'), findsOneWidget);
    expect(find.text('Avg HRV'), findsOneWidget);
    expect(find.text('Mobility / Stretching'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0);
    expect(ring.color, Colors.grey);
    for (final sample in [
      '7 hr 30 min',
      '82',
      '68 ms',
      '3 of 5 completed',
      'Feeling good',
      '7.2 hr',
    ]) {
      expect(find.text(sample), findsNothing);
    }
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'View Details'))
          .onPressed,
      isNotNull,
    );
    await _tap(tester, _recentNotesLink());
    expect(
      find.text('No notes yet. Tap Add Note to write one.'),
      findsOneWidget,
    );
    expect(find.text('Sleep Last Night'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Overview follows wake-up dates, latest notes, edits and deletes',
    (tester) async {
      await _tallViewport(tester);
      final firestore = await _openRecovery(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final previousDay = DateTime(now.year, now.month, now.day - 1);
      final owner = firestore.collection('users').doc(_uid);
      final sleep = owner.collection('sleep');
      final notes = owner.collection('recovery_notes');
      await sleep.doc('older').set({
        'date': previousDay.toIso8601String(),
        'hours': 6,
      });
      await sleep.doc('bad-date').set({'date': 'invalid', 'hours': 10});
      await sleep.doc('bad-hours').set({
        'date': today.toIso8601String(),
        'hours': double.nan,
      });
      await sleep.doc('future-day').set({
        'date': DateTime(now.year, now.month, now.day + 1).toIso8601String(),
        'hours': 10,
      });
      await notes.doc('older').set({
        'date': previousDay.toIso8601String(),
        'title': 'Older note',
        'body': 'Older text',
      });
      await notes.doc('bad-date').set({'date': '', 'title': 'Undated note'});
      await tester.pumpAndSettle();
      expect(find.text('No sleep logged for last night'), findsOneWidget);
      expect(find.text('Older note'), findsOneWidget);
      expect(find.text('Undated note'), findsNothing);

      final latestSleep = sleep.doc('today');
      final latestNote = notes.doc('today');
      await latestSleep.set({
        'date': today.toUtc().toIso8601String(),
        'hours': 7.5,
      });
      await latestNote.set({
        'date': today.toIso8601String(),
        'title': 'Latest note',
        'body': 'Actual recovery note',
      });
      await tester.pumpAndSettle();
      expect(find.text('7 hr 30 min'), findsOneWidget);
      expect(find.text('Latest note'), findsOneWidget);
      expect(find.text('Actual recovery note'), findsOneWidget);
      expect(find.text(formatDate(today)), findsOneWidget);
      expect(find.text('Older note'), findsNothing);
      expect(
        tester
            .widgetList<ProgressBar>(find.byType(ProgressBar))
            .map((bar) => bar.value),
        contains(7.5 / 8),
      );

      await latestSleep.update({'hours': 9});
      await latestNote.update({'title': 'Edited note'});
      await tester.pumpAndSettle();
      expect(find.text('9 hr 0 min'), findsOneWidget);
      expect(find.text('Edited note'), findsOneWidget);
      expect(
        tester
            .widgetList<ProgressBar>(find.byType(ProgressBar))
            .map((bar) => bar.value),
        contains(1.0),
      );
      await latestSleep.delete();
      await latestNote.delete();
      await tester.pumpAndSettle();
      expect(find.text('No sleep logged for last night'), findsOneWidget);
      expect(find.text('Older note'), findsOneWidget);

      final screen = tester.widget<RecoveryScreen>(find.byType(RecoveryScreen));
      screen.sleep!.bind('other-account');
      screen.notes!.bind('other-account');
      await screen.settings!.bind('other-account');
      await tester.pumpAndSettle();
      expect(find.text('No recovery notes yet.'), findsOneWidget);
      expect(find.text('Older note'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Saving settings updates both Overview and Sleep, and persists', (
    tester,
  ) async {
    await _tallViewport(tester);
    final firestore = await _openRecovery(tester);
    final preferences = firestore.doc('users/$_uid/settings/recovery');
    final now = DateTime.now();
    await firestore.doc('users/$_uid/sleep/night').set({
      'date': now.toIso8601String(),
      'hours': 7.5,
    });
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.settings));
    expect(find.text('Recovery Settings'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save Settings');
    await tester.enterText(_goalInput(), 'NaN');
    await _tap(tester, save);
    expect(
      find.text('Enter a sleep goal between 1 and 24 hours'),
      findsOneWidget,
    );
    expect((await preferences.get()).exists, isFalse);

    await tester.enterText(_goalInput(), '7.5');
    await _tap(tester, find.byType(SwitchListTile));
    await _tap(tester, save);
    expect(find.text('Recovery settings saved'), findsOneWidget);
    expect(find.text('Goal: 7.5 hr'), findsOneWidget);
    expect(find.text('Hidden'), findsOneWidget);
    expect((await preferences.get()).data(), {
      'sleepGoalHours': 7.5,
      'showHrv': false,
    });
    await _tap(tester, _tab('Sleep'));
    expect(find.textContaining('Goal: 7.5 hr'), findsOneWidget);
    expect(tester.widget<ProgressBar>(find.byType(ProgressBar)).value, 1);

    await _tap(tester, find.byIcon(Icons.settings));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await _tap(tester, find.byType(BackButton));
    expect(find.text('Last sleep'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Denied settings save keeps the draft and the old sleep goal', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore(
      securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /users/{uid}/settings/recovery {
            allow read: if true;
            allow write: if false;
          }
        }
      }
    ''',
    );
    await _openRecovery(tester, database: firestore);
    await _tap(tester, find.byIcon(Icons.settings));
    await tester.enterText(_goalInput(), '9');
    await _tap(tester, find.widgetWithText(FilledButton, 'Save Settings'));
    expect(
      find.text('Could not save recovery settings. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Recovery settings saved'), findsNothing);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('Goal: 8 hr'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Overview distinguishes loading, record errors and settings errors',
    (tester) async {
      await _tallViewport(tester);
      final firestore = FakeFirebaseFirestore(
        securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /users/{uid}/{document=**} {
            allow read: if false;
          }
        }
      }
    ''',
      );
      await _openRecovery(tester, database: firestore);
      final screen = tester.widget<RecoveryScreen>(find.byType(RecoveryScreen));
      expect(find.text('Could not load recovery settings.'), findsOneWidget);
      expect(find.text('Goal: 8 hr'), findsNothing);
      screen.sleep!.loading = true;
      screen.notes!.loading = true;
      await _tap(tester, _tab('Wellness'));
      await _tap(tester, _tab('Overview'));
      expect(find.text('Loading sleep…'), findsOneWidget);
      expect(find.text('Loading habits…'), findsOneWidget);
      expect(find.text('Loading recovery notes…'), findsOneWidget);
      await _tap(tester, find.text('View Details'));
      expect(find.text('Loading recovery measurements…'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      screen.sleep!.loading = false;
      screen.notes!.loading = false;
      screen.sleep!.error = 'Sleep records unavailable.';
      screen.notes!.error = 'Note records unavailable.';
      await _tap(tester, _tab('Wellness'));
      await _tap(tester, _tab('Overview'));
      expect(find.text('Sleep records unavailable.'), findsOneWidget);
      expect(find.text('Note records unavailable.'), findsOneWidget);
      expect(find.text('No recovery notes yet.'), findsNothing);
      expect(find.text('Habits sync issue'), findsOneWidget);
      await _tap(tester, find.text('Recovery Habits'));
      expect(find.text('Daily Recovery Habits'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Sleep records unavailable.'),
        ),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('View Details'));
      expect(find.text('Sleep records unavailable.'), findsOneWidget);
      expect(find.text('Could not load recovery settings.'), findsOneWidget);
      _expectScore(tester, null, Colors.grey);
      await _tap(tester, find.byType(BackButton));

      await _tap(tester, find.byIcon(Icons.settings));
      expect(find.text('Could not load recovery settings.'), findsOneWidget);
      expect(_goalInput(), findsNothing);
      await _tap(tester, find.text('Try again'));
      expect(find.text('Could not load recovery settings.'), findsOneWidget);
      await screen.settings!.bind(null);
      await tester.pumpAndSettle();
      expect(find.text('Sign in to edit recovery settings.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  const cases = [
    (
      tab: 'Sleep',
      shortcut: 'Log Sleep',
      formTitle: 'Log sleep',
      editTitle: 'Edit sleep',
      empty: 'No sleep logged yet. Tap Log Sleep to add a night.',
      field: 'Hours slept',
      invalid: '25',
      error: 'Enter hours between 0 and 24',
      value: '7.5',
      edited: '8',
      storedValue: 7.5,
      storedEdit: 8.0,
      key: 'hours',
      path: 'sleep',
      save: 'Save',
      deleteTitle: 'Delete sleep entry?',
    ),
    (
      tab: 'Wellness',
      shortcut: 'Log Wellness',
      formTitle: 'Log wellness',
      editTitle: 'Edit wellness',
      empty: 'No check-ins yet. Tap Log Wellness to add one.',
      field: 'HRV in ms (optional)',
      invalid: '301',
      error: 'Enter HRV between 1 and 300 ms',
      value: '65',
      edited: '73',
      storedValue: 65,
      storedEdit: 73,
      key: 'hrv',
      path: 'wellness',
      save: 'Save',
      deleteTitle: 'Delete check-in?',
    ),
    (
      tab: 'Notes',
      shortcut: 'Add Note',
      formTitle: 'Add note',
      editTitle: 'Edit note',
      empty: 'No notes yet. Tap Add Note to write one.',
      field: 'Title',
      invalid: '   ',
      error: 'Please enter a title',
      value: 'After training',
      edited: 'After stretching',
      storedValue: 'After training',
      storedEdit: 'After stretching',
      key: 'title',
      path: 'recovery_notes',
      save: 'Save Note',
      deleteTitle: 'Delete note?',
    ),
  ];

  testWidgets('Recovery tabs show their own empty histories', (tester) async {
    await _openRecovery(tester);
    expect(find.text('Sleep Last Night'), findsOneWidget);
    for (final entry in cases) {
      await _tap(tester, _tab(entry.tab));
      expect(find.text(entry.empty), findsOneWidget);
      expect(find.text('Sleep Last Night'), findsNothing);
    }
    await _tap(tester, _tab('Overview'));
    expect(find.text('Sleep Last Night'), findsOneWidget);
  });

  for (final entry in cases) {
    testWidgets('Overview opens the ${entry.tab} logging form', (tester) async {
      await _openRecovery(tester);
      await _tap(tester, find.text(entry.shortcut));
      expect(find.text(entry.formTitle), findsOneWidget);
      expect(find.widgetWithText(TextFormField, entry.field), findsOneWidget);
    });

    testWidgets('${entry.tab} validates and persists create, edit and delete', (
      tester,
    ) async {
      final firestore = await _openRecovery(tester);
      final documents = firestore
          .collection('users')
          .doc(_uid)
          .collection(entry.path);
      final historyEntry = find.byType(EntryTile);
      final field = find.widgetWithText(TextFormField, entry.field);
      final save = find.widgetWithText(FilledButton, entry.save);

      await _tap(tester, _tab(entry.tab));
      expect(find.text(entry.empty), findsOneWidget);
      await _tap(tester, find.text(entry.shortcut));
      await tester.enterText(field, entry.invalid);
      await _tap(tester, save);
      expect(find.text(entry.error), findsOneWidget);
      expect((await documents.get()).docs, isEmpty);

      await tester.enterText(field, entry.value);
      await _tap(tester, save);
      expect(find.text(entry.formTitle), findsNothing);
      expect(historyEntry, findsOneWidget);
      expect(find.text(entry.empty), findsNothing);
      final created = (await documents.get()).docs.single;
      expect(created.data()[entry.key], entry.storedValue);

      await _tap(tester, historyEntry);
      expect(find.text(entry.editTitle), findsOneWidget);
      final input = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(
        double.tryParse(input.controller.text) ?? input.controller.text,
        entry.storedValue,
      );
      await tester.enterText(field, entry.edited);
      await _tap(tester, save);
      final updated = (await documents.get()).docs.single;
      expect(updated.id, created.id);
      expect(updated.data()[entry.key], entry.storedEdit);

      final delete = find.descendant(
        of: historyEntry,
        matching: find.byIcon(Icons.delete_outline),
      );
      await _tap(tester, delete);
      expect(find.text(entry.deleteTitle), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect((await documents.get()).docs.single.id, created.id);
      await _tap(tester, delete);
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect((await documents.get()).docs, isEmpty);
      expect(historyEntry, findsNothing);
      expect(find.text(entry.empty), findsOneWidget);
    });
  }
}
