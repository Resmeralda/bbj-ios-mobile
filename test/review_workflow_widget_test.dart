import 'dart:async';

import 'package:bjj_app/data/review_store.dart';
import 'package:bjj_app/data/role_store.dart';
import 'package:bjj_app/main.dart';
import 'package:bjj_app/models/technique.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:bjj_app/screens/admin_dashboard_screen.dart';
import 'package:bjj_app/screens/profile_screen.dart';
import 'package:bjj_app/screens/technique_detail_screen.dart';
import 'package:bjj_app/screens/trainer_access_screen.dart';
import 'package:bjj_app/services/practiced_service.dart';
import 'package:bjj_app/services/technique_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = '/home/profile';
const _uid = 'test-user';
const _publication = {
  'name': 'Knee shield',
  'instructor': 'Coach',
  'category': 'Guard',
  'difficulty': 'Beginner',
  'description': 'Setup and practice.',
  'videoUrl': 'https://youtu.be/abcdefghijk',
};

typedef _StoreFactory = ReviewStore Function(
  RoleStore roles,
  String? Function() uid,
  FakeFirebaseFirestore db,
);

Future<void> _open(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  String? role,
  String path = _profile,
  _StoreFactory? factory,
}) async {
  await tester.binding.setSurfaceSize(const Size(640, 1500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: _uid, displayName: 'Test user'),
  );
  final roles = RoleStore(firestore: db);
  final profiles = ProfileStore(firestore: db);
  if (role != null) await db.doc('user_roles/$_uid').set({'role': role});
  final subscription = bindAuthStores(
    auth,
    roles: roles,
    bindPersonalData: (user) =>
        profiles.bind(user?.uid, authName: user?.displayName),
  );
  String? uid() => auth.currentUser?.uid;
  final router = createAppRouter(
    auth,
    roles: roles,
    profiles: profiles,
    reviews:
        factory?.call(roles, uid, db) ??
        ReviewStore(roles: roles, currentUid: uid, firestore: db),
  );
  addTearDown(roles.dispose);
  addTearDown(profiles.dispose);
  addTearDown(subscription.cancel);
  addTearDown(router.dispose);
  await tester.pumpWidget(BjjFitnessApp(router: router));
  await tester.pumpAndSettle();
  router.go(path);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _videoFilter(String status) =>
    find.byKey(ValueKey('video-filter-$status'));

Future<void> _filterVideo(WidgetTester tester, String status) async {
  await tester.ensureVisible(_videoFilter(status));
  await tester.tap(_videoFilter(status));
  await tester.pumpAndSettle();
}

Future<void> _input(WidgetTester tester, String label, String value) =>
    tester.enterText(find.widgetWithText(TextFormField, label), value);

Future<void> _choose(WidgetTester tester, String label, String value) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, label));
  await tester.pumpAndSettle();
  await _tap(tester, value);
}

Future<void> _technique(
  WidgetTester tester, {
  String url = 'https://youtu.be/abcdefghijk',
}) async {
  await _input(tester, 'Technique name', 'Knee shield');
  await _input(tester, 'Instructor', 'Coach');
  await _choose(tester, 'Category', 'Guard');
  await _choose(tester, 'Difficulty', 'Beginner');
  await _input(tester, 'Description', 'Setup and practice.');
  await _input(tester, 'YouTube URL', url);
}

class _DelayedSubmissionStore extends ReviewStore {
  _DelayedSubmissionStore(
    RoleStore roles,
    String? Function() uid,
    FakeFirebaseFirestore db,
  ) : super(roles: roles, currentUid: uid, firestore: db);

  final first = Completer<void>();
  final ids = <String>[];

  @override
  Future<void> submit(
    ReviewAccess access,
    String id,
    Technique technique,
  ) async {
    ids.add(id);
    if (ids.length == 1) await first.future;
    await super.submit(access, id, technique);
  }
}

class _UnavailableReviewStore extends ReviewStore {
  _UnavailableReviewStore(
    RoleStore roles,
    String? Function() uid,
    FakeFirebaseFirestore db,
  ) : super(roles: roles, currentUid: uid, firestore: db);

  @override
  Stream<ReviewSnapshot<TrainerApplication>> watchApplications() =>
      Stream.error(StateError('Applications unavailable'));

  @override
  Stream<ReviewSnapshot<TechniqueSubmission>> watchModeration() =>
      Stream.error(StateError('Submissions unavailable'));
}

void main() {
  testWidgets(
    'A swiped draft returns, then vanishes from an open sheet on Trainer revocation',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _open(tester, db, role: 'trainer');
      await _tap(tester, 'Submit Technique');
      await _input(tester, 'Technique name', 'Sensitive draft');
      await tester.drag(
        find.text('Submit Technique').last,
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clear Draft'), findsNothing);
      await _tap(tester, 'Submit Technique');
      expect(find.text('Sensitive draft'), findsOneWidget);
      await db.doc('user_roles/$_uid').delete();
      await tester.pumpAndSettle();
      expect(find.text('Sensitive draft'), findsNothing);
      expect(
        find.text('This submission draft is no longer available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'All dashboard sections fit with large text and direct Trainers can be revoked',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('user_roles/admin').set({'role': 'admin'});
      await db.doc('user_roles/external').set({
        'role': 'trainer',
        'accountName': 'Direct Coach',
        'accountEmail': 'direct@example.test',
      });
      final roles = RoleStore(firestore: db)..bind('admin');
      addTearDown(roles.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      final store = ReviewStore(
        roles: roles,
        currentUid: () => 'admin',
        firestore: db,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: AdminDashboardScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in [
        'Video Submissions',
        'Published Techniques',
        'Trainer Requests',
      ]) {
        final target = find.text(tab);
        expect(tester.getRect(target).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(target).right, lessThanOrEqualTo(320));
        await _tap(tester, tab);
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('direct@example.test'), findsOneWidget);
      await _tap(tester, 'Direct Coach');
      await _tap(tester, 'Revoke access');
      await _tap(tester, 'Revoke');
      expect((await db.doc('user_roles/external').get()).exists, isFalse);
      final record = await db.doc('trainer_requests/external').get();
      expect(record.data()?['status'], 'revoked');
      expect(record.data()?['accountName'], 'Direct Coach');
    },
  );

  testWidgets(
    'Dashboard reports unreadable input as an error rather than an empty list',
    (tester) async {
      await _open(
        tester,
        FakeFirebaseFirestore(),
        role: 'admin',
        path: '$_profile/admin',
        factory: _UnavailableReviewStore.new,
      );
      expect(find.text('Could not load trainer requests.'), findsOneWidget);
      expect(find.text('No pending trainer requests.'), findsNothing);
      await _tap(tester, 'Video Submissions');
      expect(find.text('Could not load video submissions.'), findsOneWidget);
      expect(find.text('No video submissions yet.'), findsNothing);
    },
  );

  testWidgets(
    'Open technique details update and can go back after removal or a load error',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: _uid),
      );
      final ref = db.doc('techniques/original');
      final practiced = db.doc('users/$_uid/practicedTechniques/original');
      final favorite = db.doc('users/$_uid/favorites/original');
      await ref.set({..._publication, 'videoUrl': ''});
      await practiced.set({'techniqueId': 'original'});
      await favorite.set({'techniqueId': 'original'});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TechniqueDetailScreen(
                      techniqueId: 'original',
                      techniques: TechniqueService(firestore: db),
                      practiced: PracticedService(firestore: db, auth: auth),
                    ),
                  ),
                ),
                child: const Text('Open technique'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, 'Open technique');
      expect(find.text('Knee shield'), findsWidgets);
      await ref.update({'name': 'Updated shield'});
      await tester.pumpAndSettle();
      expect(find.text('Updated shield'), findsWidgets);
      await ref.delete();
      await tester.pumpAndSettle();
      expect(find.text('Technique not found.'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      await ref.set({..._publication, 'name': 42});
      await tester.pumpAndSettle();
      expect(find.text('Could not load technique.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open technique'), findsOneWidget);
      expect((await practiced.get()).exists, isTrue);
      expect((await favorite.get()).exists, isTrue);
    },
  );

  testWidgets(
    'Student Profile validates, submits and shows trainer request status',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _open(tester, db, path: '$_profile/submissions');
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Submit Technique'), findsNothing);
      expect(find.text('No trainer request submitted.'), findsOneWidget);
      await _tap(tester, 'Request Trainer Access');
      await _tap(tester, 'Send request');
      expect(find.text('Required'), findsNWidgets(4));
      await _input(tester, 'Academy or dojo', 'Test academy');
      await _choose(tester, 'Position', 'Dojo Staff');
      await _choose(tester, 'Belt rank (optional)', 'Not applicable');
      await _input(
        tester,
        'Academy website or contact information',
        'contact@example.test',
      );
      await _input(tester, 'Reason for requesting access', 'Help teach.');
      await _tap(tester, 'Send request');
      final path = db.doc('trainer_requests/$_uid');
      final original = (await path.get()).data()!;
      expect(original['applicantUid'], _uid);
      expect(find.text('Saved successfully.'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Request Trainer Access'), findsNothing);
      await _tap(tester, 'Edit pending application');
      expect(find.text('Test academy'), findsOneWidget);
      await _input(tester, 'Academy or dojo', 'Updated academy');
      await _tap(tester, 'Save changes');
      final updated = (await path.get()).data()!;
      expect(updated['academy'], 'Updated academy');
      expect(updated['requestedAt'], original['requestedAt']);
      expect(updated['updatedAt'], isNotNull);
      await _tap(tester, 'Edit pending application');
      await path.update({
        'status': 'rejected',
        'reviewReason': 'Please clarify the contact.',
      });
      await _tap(tester, 'Save changes');
      expect(
        find.text('This request has changed. Reopen it from Profile.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Please clarify the contact.'), findsOneWidget);
      expect(find.text('Request Trainer Access'), findsOneWidget);
      await _tap(tester, 'View application');
      expect(find.text('Updated academy'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _open(tester, db);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Please clarify the contact.'), findsOneWidget);
      expect(find.text('No trainer request submitted.'), findsNothing);
    },
  );

  testWidgets(
    'Trainer keeps a failed draft and sees only their own submissions',
    (tester) async {
      final db = FakeFirebaseFirestore();
      late _DelayedSubmissionStore store;
      await db.doc('technique_submissions/other').set({
        ..._publication,
        'name': 'Unrelated submission',
        'submitterUid': 'someone else',
        'status': 'pending',
      });
      await _open(
        tester,
        db,
        role: 'trainer',
        factory: (roles, uid, db) =>
            store = _DelayedSubmissionStore(roles, uid, db),
      );
      expect(find.text('Request Trainer Access'), findsNothing);
      await _tap(tester, 'My Submissions');
      expect(find.text('No video submissions yet.'), findsOneWidget);
      await _tap(tester, 'Submit Technique');
      await _technique(tester, url: 'https://not-youtube.test/abcdefghijk');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, 'Submit Technique');
      expect(find.text('Knee shield'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      await _tap(tester, 'Submit for review');
      expect(find.text('Enter a supported YouTube video URL.'), findsOneWidget);
      await _input(tester, 'YouTube URL', 'https://youtu.be/abcdefghijk');
      final save = find.text('Submit for review');
      await tester.tap(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.ids, hasLength(1));
      expect(find.text('Saving…'), findsOneWidget);
      store.first.completeError(Exception('Fake write failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Knee shield'), findsOneWidget);
      await _tap(tester, 'Submit for review');
      expect(store.ids, [store.ids.first, store.ids.first]);
      expect(find.text('Knee shield'), findsOneWidget);
      expect(find.text('Unrelated submission'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
      await _tap(tester, 'Submit Technique');
      expect(find.text('Knee shield'), findsOneWidget); // Saved list row only.
      await _input(tester, 'Technique name', 'Discard this');
      await _tap(tester, 'Clear Draft');
      await _tap(tester, 'Cancel');
      expect(find.text('Discard this'), findsOneWidget);
      await _tap(tester, 'Clear Draft');
      await _tap(tester, 'Clear');
      expect(find.text('Discard this'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await db.doc('user_roles/$_uid').delete();
      await tester.pumpAndSettle();
      expect(find.byType(MySubmissionsScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Administrator reviews trainer requests and moderates the submission queue',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final request = db.doc('trainer_requests/applicant');
      await request.set({
        'academy': 'Applicant academy',
        'position': 'Instructor/Coach',
        'belt': 'Black',
        'contact': 'test@example.test',
        'reason': 'Teach classes',
        'applicantUid': 'applicant',
        'accountName': 'Coach Applicant',
        'accountEmail': 'applicant@example.test',
        'status': 'pending',
      });
      for (final (id, name) in [
        ('submission_abcdefghijklmnopqrst', 'Publish me'),
        ('submission_12345678901234567890', 'Reject me'),
      ]) {
        await db.doc('technique_submissions/$id').set({
          ..._publication,
          'name': name,
          'submitterUid': 'trainer',
          'accountName': 'Coach Video',
          'accountEmail': 'video@example.test',
          'status': 'pending',
        });
      }
      await _open(tester, db, role: 'admin', path: '$_profile/admin');
      expect(find.textContaining('applicant@example.test'), findsOneWidget);
      await _tap(tester, 'Coach Applicant');
      expect(find.text('Teach classes'), findsOneWidget);
      await _tap(tester, 'Approve');
      expect((await db.doc('user_roles/applicant').get()).data(), {
        'role': 'trainer',
      });
      if (find.text('Revoke access').evaluate().isEmpty) {
        await _tap(tester, 'Coach Applicant');
      }
      await _tap(tester, 'Revoke access');
      await _tap(tester, 'Cancel');
      expect((await request.get()).data()?['status'], 'approved');
      await _tap(tester, 'Revoke access');
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason (optional)'),
        'Season ended.',
      );
      await _tap(tester, 'Revoke');
      expect((await request.get()).data()?['status'], 'revoked');
      expect((await request.get()).data()?['reviewReason'], 'Season ended.');
      expect((await db.doc('user_roles/applicant').get()).exists, isFalse);
      expect(find.text('No pending trainer requests.'), findsOneWidget);
      if (find.text('Reinstate Access').evaluate().isEmpty) {
        await _tap(tester, 'Coach Applicant');
      }
      await _tap(tester, 'Reinstate Access');
      await _tap(tester, 'Reinstate');
      expect((await request.get()).data()?['status'], 'approved');
      expect(
        (await db.doc('user_roles/applicant').get()).data()?['role'],
        'trainer',
      );

      await _tap(tester, 'Video Submissions');
      expect(tester.widget<ChoiceChip>(_videoFilter('all')).selected, isTrue);
      await _filterVideo(tester, 'pending');
      await _tap(tester, 'Publish me');
      expect(find.text('Submitted by: Coach Video'), findsOneWidget);
      expect(find.text('video@example.test'), findsOneWidget);
      expect(find.text('Preview YouTube video'), findsOneWidget);
      await _tap(tester, 'Approve');
      expect(find.text('Publish me'), findsNothing);
      await _tap(tester, 'Reject me');
      await _tap(tester, 'Reject');
      expect(
        (await db.collection('techniques').get()).docs.single.data()['name'],
        'Publish me',
      );
      expect(find.text('No submissions match this status.'), findsOneWidget);
      await _filterVideo(tester, 'rejected');
      expect(
        tester
            .widget<DropdownButton<SubmissionFilter?>>(
              find.byType(DropdownButton<SubmissionFilter?>),
            )
            .value,
        SubmissionFilter.rejected,
      );
      await _tap(tester, 'Reject me');
      await _tap(tester, 'Reopen for Review');
      await _tap(tester, 'Reopen');
      expect(find.text('Reject me'), findsNothing);
      await tester.tap(find.byType(DropdownButton<SubmissionFilter?>));
      await tester.pumpAndSettle();
      await _tap(tester, 'Pending');
      expect(
        tester.widget<ChoiceChip>(_videoFilter('pending')).selected,
        isTrue,
      );
      expect(find.text('Reject me'), findsOneWidget);
      expect(find.text('Publish me'), findsNothing);
      await _filterVideo(tester, 'all');
      expect(find.text('Publish me'), findsOneWidget);
    },
  );

  testWidgets(
    'Reviewed trainer and video cleanup confirms deletion and hides legacy account IDs',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final application = db.doc('trainer_requests/legacy-secret-uid');
      await application.set({
        'applicantUid': 'legacy-secret-uid',
        'status': 'revoked',
      });
      final rejected = db.doc('technique_submissions/rejected-record');
      await rejected.set({
        ..._publication,
        'name': 'Rejected video',
        'submitterUid': 'legacy-secret-uid',
        'status': 'rejected',
      });
      await _open(tester, db, role: 'admin', path: '$_profile/admin');
      await _tap(tester, 'Trainer account');
      expect(find.textContaining('legacy-secret-uid'), findsNothing);
      expect(find.textContaining('Account ID'), findsNothing);
      expect(find.text('Reinstate Access'), findsOneWidget);
      await _tap(tester, 'Delete application');
      expect(
        find.textContaining('removes the previous decision'),
        findsOneWidget,
      );
      await _tap(tester, 'Cancel');
      expect((await application.get()).exists, isTrue);
      await _tap(tester, 'Delete application');
      await _tap(tester, 'Delete application');
      expect((await application.get()).exists, isFalse);
      await _tap(tester, 'Video Submissions');
      await _tap(tester, 'Rejected video');
      expect(find.text('Submitted by: Trainer submitter'), findsOneWidget);
      expect(find.textContaining('legacy-secret-uid'), findsNothing);
      await _tap(tester, 'Delete submission');
      await _tap(tester, 'Delete submission');
      expect((await rejected.get()).exists, isFalse);
      expect(find.text('No video submissions yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'All statuses sorts submissions and the Removed filter supports restoring and archiving',
    (tester) async {
      final db = FakeFirebaseFirestore();
      const linked = 'submission_abcdefghijklmnopqrst';
      const missing = 'submission_12345678901234567890';
      for (final (id, name, status, day) in [
        ('pending-old', 'Older pending', 'pending', 1),
        ('pending-new', 'Newer pending', 'pending', 3),
        (linked, 'Restore this', 'approved', 2),
        ('rejected', 'Rejected row', 'rejected', 4),
        (missing, 'Legacy missing', 'approved', 5),
      ]) {
        await db.doc('technique_submissions/$id').set({
          ..._publication,
          'name': name,
          'submitterUid': 'trainer',
          'status': status,
          'submittedAt': Timestamp.fromDate(DateTime(2026, 1, day)),
        });
      }
      final publication = db.doc('techniques/$linked');
      await publication.set({..._publication, 'name': 'Restore this'});
      await _open(tester, db, role: 'admin', path: '$_profile/admin');
      await _tap(tester, 'Video Submissions');
      final positions = [
        'Newer pending',
        'Older pending',
        'Restore this',
        'Rejected row',
        'Legacy missing',
      ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
      expect(positions, orderedEquals([...positions]..sort()));
      await _filterVideo(tester, 'pending');
      expect(find.text('Restore this'), findsNothing);
      await _tap(tester, 'Published Techniques');
      await _tap(tester, 'Restore this');
      await _tap(tester, 'Remove');
      await _tap(tester, 'Delete');
      expect((await publication.get()).exists, isFalse);
      expect(
        (await db.doc('technique_submissions/$linked').get())
            .data()?['publicationState'],
        'removed',
      );

      await _tap(tester, 'Video Submissions');
      await _filterVideo(tester, 'removed');
      expect(find.textContaining('Removed from Library'), findsNWidgets(2));
      await _tap(tester, 'Legacy missing');
      await _tap(tester, 'Archive Review Record');
      await _tap(tester, 'Archive');
      expect(find.text('Legacy missing'), findsNothing);
      expect((await db.doc('techniques/$missing').get()).exists, isFalse);

      await _tap(tester, 'Restore this');
      await _tap(tester, 'Republish');
      await _tap(tester, 'Republish');
      expect((await publication.get()).data()?['name'], 'Restore this');
      expect(find.text('Restore this'), findsNothing);
      await _filterVideo(tester, 'approved');
      expect(find.textContaining('Approved · Published'), findsOneWidget);
      await _tap(tester, 'Restore this');
      await _tap(tester, 'Archive Review Record');
      await _tap(tester, 'Archive');
      expect(find.text('Restore this'), findsNothing);
      expect((await publication.get()).exists, isTrue);
    },
  );

  testWidgets(
    'Published catalog can be added, edited and removed without deleting private records',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _open(tester, db, role: 'admin', path: '$_profile/admin');
      await _tap(tester, 'Video Submissions');
      expect(find.text('No video submissions yet.'), findsOneWidget);
      await _tap(tester, 'Published Techniques');
      expect(find.text('No published techniques available.'), findsOneWidget);
      await _tap(tester, 'Add Published Technique');
      await _technique(tester);
      await _tap(tester, 'Save technique');
      final catalog = db.collection('techniques');
      final id = (await catalog.get()).docs.single.id;
      final favorite = db.doc('users/student/favorites/$id');
      final practiced = db.doc('users/student/practicedTechniques/$id');
      await favorite.set({'techniqueId': id});
      await practiced.set({'techniqueId': id});
      await _tap(tester, 'Knee shield');
      await _tap(tester, 'Edit');
      expect(find.text('Knee shield'), findsWidgets);
      await _input(tester, 'Technique name', 'Edited technique');
      await _tap(tester, 'Save technique');
      expect((await catalog.doc(id).get()).data()?['name'], 'Edited technique');
      if (find.text('Remove').evaluate().isEmpty) {
        await _tap(tester, 'Edited technique');
      }
      await _tap(tester, 'Remove');
      await _tap(tester, 'Delete');
      expect((await catalog.doc(id).get()).exists, isFalse);
      expect((await favorite.get()).exists, isTrue);
      expect((await practiced.get()).exists, isTrue);
      expect(find.text('No published techniques available.'), findsOneWidget);
    },
  );
}
