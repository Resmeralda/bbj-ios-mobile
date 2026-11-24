import 'package:bjj_app/screens/history_screen.dart';
import 'package:bjj_app/screens/log_session_screen.dart';
import 'package:bjj_app/session_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Training form prefills type and rejects invalid statistics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = FakeFirebaseFirestore();
    final store = SessionStore(firestore: db)..bind('athlete');
    addTearDown(store.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/log'),
              child: const Text('Start'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'log',
              builder: (_, _) =>
                  LogSessionScreen(store: store, initialType: 'Open Mat'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Open Mat'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NaN');
    await tester.enterText(fields.at(1), '-2');
    await tester.tap(find.text('Save Session'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a finite number above 0'), findsOneWidget);
    expect(find.text('Enter a whole number of 0 or more'), findsOneWidget);
    expect(store.sessions, isEmpty);

    await tester.enterText(fields.at(0), '1.5');
    await tester.enterText(fields.at(1), '3');
    await tester.tap(find.text('Save Session'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(store.sessions.single.type, 'Open Mat');
    expect(store.sessions.single.hours, 1.5);
    expect(store.sessions.single.rounds, 3);
  });

  testWidgets('Training history shows a failed load instead of empty results', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/athlete/sessions/bad').set({'hours': 'corrupt'});
    final store = SessionStore(firestore: db)..bind('athlete');
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HistoryBody(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load sessions. Check your connection.'),
      findsOneWidget,
    );
    expect(find.textContaining('No sessions yet'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
