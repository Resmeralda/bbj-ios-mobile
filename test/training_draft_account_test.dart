import 'package:bjj_app/models/training_session.dart';
import 'package:bjj_app/screens/history_screen.dart';
import 'package:bjj_app/screens/log_session_screen.dart';
import 'package:bjj_app/session_store.dart';
import 'package:bjj_app/widgets/form_helpers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Training history confirmation and Undo keep their original account',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final store = SessionStore(firestore: firestore)..bind('first');
      addTearDown(store.dispose);
      final session = TrainingSession(
        id: 'session',
        type: sessionTypes.first,
        date: DateTime.now(),
        hours: 1,
        rounds: 1,
        techniques: '',
        notes: 'First account',
      );
      final first = firestore.doc('users/first/sessions/session');
      final second = firestore.doc('users/second/sessions/session');
      await first.set(session.toMap());
      await second.set({...session.toMap(), 'notes': 'Second account'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryBody(store: store)),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> swipeToDelete() async {
        await tester.drag(
          find.descendant(
            of: find.byType(HistoryBody),
            matching: find.byType(Dismissible),
          ),
          const Offset(-740, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete session?'), findsOneWidget);
      }

      Future<void> confirm() async {
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
      }

      await swipeToDelete();
      store.bind('second');
      await tester.pumpAndSettle();
      await confirm();
      expect((await first.get()).exists, isTrue);
      expect((await second.get()).exists, isTrue);

      store.bind('first');
      await tester.pumpAndSettle();
      await swipeToDelete();
      await confirm();
      expect((await first.get()).exists, isFalse);
      final undo = find.text('Undo');
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect((await first.get()).exists, isTrue);

      await swipeToDelete();
      await confirm();
      store.bind('second');
      await tester.pumpAndSettle();
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect((await first.get()).exists, isFalse);
      expect((await second.get()).data()!['notes'], 'Second account');
    },
  );

  testWidgets('A stale training editor cannot update or delete a session', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SessionStore(firestore: firestore)..bind('first');
    addTearDown(store.dispose);
    final session = TrainingSession(
      id: 'session',
      type: sessionTypes.first,
      date: DateTime.now(),
      hours: 1,
      rounds: 1,
      techniques: '',
      notes: 'First account',
    );
    final first = firestore.doc('users/first/sessions/session');
    final second = firestore.doc('users/second/sessions/session');
    await first.set(session.toMap());
    await second.set({...session.toMap(), 'notes': 'Second account'});
    await tester.pumpWidget(
      MaterialApp(
        home: LogSessionScreen(session: session, store: store),
      ),
    );
    store.bind('second');
    await tester.pumpAndSettle();
    final save = find.byType(FilledButton);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text(staleAccountMessage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect((await first.get()).data()!['notes'], 'First account');
    expect((await second.get()).data()!['notes'], 'Second account');
  });
}
