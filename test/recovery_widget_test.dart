import 'package:bjj_app/data/collection_store.dart';
import 'package:bjj_app/models/health_models.dart';
import 'package:bjj_app/screens/recovery_screen.dart';
import 'package:bjj_app/widgets/form_helpers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<FakeFirebaseFirestore> _openRecovery(WidgetTester tester) async {
  final firestore = FakeFirebaseFirestore();
  await tester.pumpWidget(
    MaterialApp(
      home: RecoveryScreen(
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
      ),
    ),
  );
  await tester.pumpAndSettle();
  return firestore;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.text(label),
);

void main() {
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
