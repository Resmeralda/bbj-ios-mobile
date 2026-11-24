import 'package:bjj_app/models/training_session.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/screens/home_screen.dart';
import 'package:bjj_app/session_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingSession session(String id, DateTime date, {String techniques = ''}) =>
    TrainingSession(
      id: id,
      type: 'Gi Class',
      date: date,
      hours: 1.25,
      rounds: 4,
      techniques: techniques,
      notes: id,
    );

void main() {
  testWidgets('Home reflects live sessions, goals and account changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = FakeFirebaseFirestore();
    final profiles = ProfileStore(firestore: db)..bind('first');
    final sessions = SessionStore(firestore: db)..bind('first');
    addTearDown(profiles.dispose);
    addTearDown(sessions.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(store: profiles, sessions: sessions),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 4 sessions'), findsOneWidget);
    expect(find.text('No training sessions this week.'), findsOneWidget);

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    sessions.add(
      session('Current session', monday, techniques: 'Guard, Passing'),
    );
    sessions.add(
      session(
        'Second session',
        monday.add(const Duration(hours: 1)),
        techniques: ' guard , Sweep',
      ),
    );
    sessions.add(
      session('Previous week', monday.subtract(const Duration(seconds: 1))),
    );
    sessions.add(
      session('Next week', DateTime(monday.year, monday.month, monday.day + 7)),
    );
    await tester.pumpAndSettle();
    expect(sessions.sessionsForWeek(monday).map((s) => s.id), [
      'Second session',
      'Current session',
    ]);
    expect(find.text('2 of 4 sessions'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Current session'), findsOneWidget);
    expect(find.textContaining('Previous week'), findsNothing);
    expect(find.textContaining('Next week'), findsNothing);

    await profiles.save(
      profiles.profile.copyWith(weeklyGoal: 1),
      account: profiles.account,
    );
    sessions.update(
      session('Current session', monday).copyWith(hours: 2.75, rounds: 6),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 of 1 sessions'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('You reached your weekly goal!'), findsOneWidget);

    sessions.delete('Current session');
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 sessions'), findsOneWidget);
    expect(find.textContaining('Current session'), findsNothing);
    profiles.bind('second', authName: 'Second athlete');
    sessions.bind('second');
    await tester.pumpAndSettle();
    expect(find.text('Hi, Second athlete!'), findsOneWidget);
    expect(find.text('0 of 4 sessions'), findsOneWidget);
    expect(find.textContaining('Second session'), findsNothing);
  });
}
