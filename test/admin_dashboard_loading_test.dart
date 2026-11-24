import 'dart:async';

import 'package:bjj_app/data/review_store.dart';
import 'package:bjj_app/data/role_store.dart';
import 'package:bjj_app/models/technique.dart';
import 'package:bjj_app/screens/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source<T> {
  final _streams = <StreamController<ReviewSnapshot<T>>>[];
  int starts = 0;
  int stops = 0;
  bool failToOpen = false;

  Stream<ReviewSnapshot<T>> watch() {
    if (failToOpen) throw StateError('The query could not be opened.');
    final controller = StreamController<ReviewSnapshot<T>>(
      onListen: () => starts++,
      onCancel: () => stops++,
    );
    _streams.add(controller);
    return controller.stream;
  }

  void emit(List<T> rows, {bool fromCache = false}) =>
      _streams.last.add((rows: rows, fromCache: fromCache));

  void error(Object error) => _streams.last.addError(error);

  void close() {
    for (final stream in _streams) {
      unawaited(stream.close());
    }
  }
}

class _DashboardStore extends ReviewStore {
  _DashboardStore({required super.roles, required super.currentUid});

  final applications = _Source<TrainerApplication>();
  final trainers = _Source<TrainerApplication>();
  final submissions = _Source<TechniqueSubmission>();
  final catalog = _Source<Technique>();

  List<_Source<Object>> get sources => [
    applications,
    trainers,
    submissions,
    catalog,
  ];

  @override
  Stream<ReviewSnapshot<TrainerApplication>> watchApplications() =>
      applications.watch();
  @override
  Stream<ReviewSnapshot<TrainerApplication>> watchTrainerRoles() =>
      trainers.watch();
  @override
  Stream<ReviewSnapshot<TechniqueSubmission>> watchModeration() =>
      submissions.watch();
  @override
  Stream<ReviewSnapshot<Technique>> watchTechniques() => catalog.watch();
}

class _AdminSession {
  final events = StreamController<RoleDocument>.broadcast(sync: true);
  late final roles = RoleStore.withWatch((_) => events.stream);
  late final store = _DashboardStore(roles: roles, currentUid: () => uid);
  final visible = ValueNotifier(true);
  String? uid = 'current-admin';

  Future<void> open(WidgetTester tester) async {
    roles.bind(uid);
    events.add((exists: true, role: 'admin', verified: true));
    await tester.binding.setSurfaceSize(const Size(700, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: AdminDashboardScreen(store: store),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    roles.dispose();
    unawaited(events.close());
    visible.dispose();
    for (final source in store.sources) {
      source.close();
    }
  }
}

TrainerApplication _application(String name) =>
    TrainerApplication('applicant', {
      'accountName': name,
      'academy': 'Private application detail',
      'status': 'rejected',
    });

Technique _technique(String id) => Technique(
  id: id,
  name: 'Catalog technique',
  category: 'Guard',
  difficulty: 'Beginner',
  description: 'Catalog description',
);

TechniqueSubmission _submission(String id, String name, String status) =>
    TechniqueSubmission(id, {
      'name': name,
      'submitterUid': 'trainer',
      'status': status,
      'category': 'Guard',
      'description': 'Private video detail',
    });

Future<void> _tab(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(Tab, name));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('A different account cannot resume an offstage dashboard', (
    tester,
  ) async {
    final session = _AdminSession();
    await session.open(tester);
    final source = session.store.applications;
    source.emit([_application('Previous account application')]);
    session.store.trainers.emit([]);
    await tester.pump();
    expect(find.text('Previous account application'), findsOneWidget);
    session.visible.value = false;
    await tester.pump();
    session.uid = null;
    session.roles.bind(null);
    session.uid = 'different-admin';
    session.roles.bind(session.uid);
    session.events.add((exists: true, role: 'admin', verified: true));
    session.visible.value = true;
    await tester.pump();
    expect(find.text('Administrator access is unavailable.'), findsOneWidget);
    expect(
      find.text('Previous account application', skipOffstage: false),
      findsNothing,
    );
    expect(source.starts, 1);
    expect(source.stops, 1);
    await session.close(tester);
  });

  testWidgets(
    'Visited tabs share one catalog listener and retain filters and live results',
    (tester) async {
      final session = _AdminSession();
      await session.open(tester);
      final store = session.store;
      expect(store.sources.map((source) => source.starts), [1, 1, 0, 0]);
      store.applications.emit([_application('Initial applicant')]);
      store.trainers.emit([]);
      await tester.pump();
      expect(find.text('Initial applicant'), findsOneWidget);
      await _tab(tester, 'Video Submissions');
      expect(store.sources.map((source) => source.starts), [1, 1, 1, 1]);
      store.catalog.emit([_technique('approved')]);
      store.submissions.emit([
        _submission('approved', 'Approved submission', 'approved'),
      ]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-filter-pending')));
      await tester.pump();
      expect(find.text('Approved submission'), findsNothing);

      await _tab(tester, 'Published Techniques');
      expect(find.text('Catalog technique'), findsOneWidget);
      store.submissions.emit([
        _submission('approved', 'Approved submission', 'approved'),
        _submission('new', 'New submission', 'pending'),
      ]);
      await tester.pump();
      await _tab(tester, 'Video Submissions');
      expect(find.text('New submission'), findsOneWidget);
      expect(find.text('Approved submission'), findsNothing);
      expect(find.text('Loading video submissions…'), findsNothing);
      expect(store.sources.map((source) => source.starts), [1, 1, 1, 1]);
      expect(store.sources.map((source) => source.stops), everyElement(0));

      session.visible.value = false;
      await tester.pump();
      expect(store.sources.map((source) => source.stops), everyElement(1));
      session.visible.value = true;
      await tester.pump();
      expect(store.sources.map((source) => source.starts), everyElement(2));
      expect(find.text('New submission'), findsOneWidget);
      expect(find.text('Refreshing publication status…'), findsOneWidget);
      store.catalog.emit([], fromCache: true);
      await tester.tap(find.byKey(const ValueKey('video-filter-approved')));
      await tester.pump();
      expect(find.text('Approved submission'), findsOneWidget);
      expect(find.textContaining('Removed from Library'), findsNothing);
      await session.close(tester);
      expect(store.sources.map((source) => source.stops), everyElement(2));
    },
  );

  testWidgets(
    'Cold timeout, warm failure and permission errors have distinct recovery paths',
    (tester) async {
      final session = _AdminSession();
      await session.open(tester);
      final source = session.store.applications;
      session.store.trainers.emit([]);
      source.emit([], fromCache: true);
      await tester.pump();
      expect(find.text('Loading trainer requests…'), findsOneWidget);
      expect(find.text('No pending trainer requests.'), findsNothing);
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Could not load trainer requests.'), findsOneWidget);
      expect(find.text('Retry trainer requests'), findsOneWidget);
      expect(find.text('Loading trainer requests…'), findsNothing);

      source.emit([_application('Verified applicant')]);
      await tester.pump();
      expect(find.text('Verified applicant'), findsOneWidget);
      source.emit([], fromCache: true);
      await tester.pump();
      expect(find.text('Refreshing trainer requests…'), findsOneWidget);
      expect(find.text('Verified applicant'), findsOneWidget);
      source.error(StateError('Temporary query failure'));
      await tester.pump();
      expect(
        find.textContaining('Showing the last loaded data'),
        findsOneWidget,
      );
      expect(find.text('Verified applicant'), findsOneWidget);
      await tester.tap(find.text('Retry trainer requests'));
      await tester.pump();
      expect(source.starts, 2);
      expect(source.stops, 1);
      expect(find.text('Verified applicant'), findsOneWidget);

      source.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pump();
      expect(find.text('Verified applicant'), findsNothing);
      expect(find.text('Could not load trainer requests.'), findsOneWidget);
      await tester.tap(find.text('Retry trainer requests'));
      await tester.pump();
      source.emit([]);
      await tester.pump();
      expect(find.text('No pending trainer requests.'), findsOneWidget);
      expect(find.text('Retry trainer requests'), findsNothing);
      await session.close(tester);
    },
  );

  testWidgets(
    'Catalog setup failures can be retried without recreating moderation',
    (tester) async {
      final session = _AdminSession();
      await session.open(tester);
      session.store.catalog.failToOpen = true;
      await _tab(tester, 'Video Submissions');
      expect(find.text('Could not verify publication status.'), findsOneWidget);
      session.store.catalog.failToOpen = false;
      await tester.tap(find.text('Retry publication status'));
      await tester.pump();
      session.store.catalog.emit([]);
      session.store.submissions.emit([]);
      await tester.pump();
      expect(find.text('No video submissions yet.'), findsOneWidget);
      expect(session.store.submissions.starts, 1);
      await session.close(tester);
    },
  );

  testWidgets(
    'Losing verified access clears retained data and an open admin dialog',
    (tester) async {
      final session = _AdminSession();
      await session.open(tester);
      final store = session.store;
      store.applications.emit([_application('Private applicant')]);
      store.trainers.emit([]);
      await tester.pump();
      await _tab(tester, 'Video Submissions');
      store.catalog.emit([]);
      store.submissions.emit([
        _submission('private', 'Private submission', 'pending'),
      ]);
      await tester.pump();
      await _tab(tester, 'Trainer Requests');
      await tester.tap(find.text('Private applicant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete application'));
      await tester.pumpAndSettle();
      expect(find.text('Delete trainer application?'), findsOneWidget);

      session.events.add((exists: true, role: 'admin', verified: false));
      await tester.pumpAndSettle();
      expect(find.text('Private applicant', skipOffstage: false), findsNothing);
      expect(
        find.text('Private submission', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Delete trainer application?'), findsNothing);
      expect(store.sources.map((source) => source.stops), everyElement(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Administrator access is unavailable.'), findsOneWidget);
      session.events.add((exists: true, role: 'admin', verified: true));
      await tester.pump();
      expect(store.sources.map((source) => source.starts), everyElement(1));
      await session.close(tester);
    },
  );
}
