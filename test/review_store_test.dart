import 'package:bjj_app/data/review_store.dart';
import 'package:bjj_app/data/role_store.dart';
import 'package:bjj_app/models/technique.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const request = {
  'academy': 'Test Academy',
  'position': 'Instructor/Coach',
  'belt': '',
  'contact': 'coach@example.test',
  'reason': 'I teach classes.',
};

const technique = {
  'name': 'Test technique',
  'instructor': 'Test coach',
  'category': 'Guard',
  'difficulty': 'Beginner',
  'description': 'A fixture description.',
  'videoUrl': 'https://youtu.be/abcdefghijk',
};

class _Workspace {
  final firestore = FakeFirebaseFirestore();
  late final roles = RoleStore(firestore: firestore);
  late final store = ReviewStore(
    roles: roles,
    currentUid: () => uid,
    firestore: firestore,
  );
  String? uid;

  Future<void> signIn(String? user) async {
    uid = user;
    roles.bind(user);
    await pumpEventQueue();
  }

  Future<void> seedRoles() async {
    await firestore.doc('user_roles/admin').set({'role': 'admin'});
    await firestore.doc('user_roles/trainer').set({'role': 'trainer'});
  }
}

void main() {
  test(
    'Unfinished fields never follow an account or a revoked authorization',
    () async {
      final workspace = _Workspace();
      addTearDown(workspace.roles.dispose);
      await workspace.seedRoles();
      await workspace.firestore.doc('user_roles/another').set({
        'role': 'trainer',
      });
      final store = workspace.store;
      await workspace.signIn('trainer');
      final first = store.openDraft(store.capture(UserRole.trainer));
      store.updateDraft(first, 'name', 'Private draft');
      expect(store.openDraft(store.capture(UserRole.trainer)), same(first));
      await workspace.signIn('another');
      expect(first.values, isEmpty);
      store.updateDraft(first, 'name', 'Late input');
      expect(first.values, isEmpty);
      final second = store.openDraft(store.capture(UserRole.trainer));
      expect(second.values, isEmpty);
      store.updateDraft(second, 'name', 'Second private draft');
      await workspace.firestore.doc('user_roles/another').delete();
      await pumpEventQueue();
      expect(second.values, isEmpty);
      await expectLater(
        store.submitDraft(second, Technique.fromMap(second.id, technique)),
        throwsStateError,
      );
      await workspace.signIn('trainer');
      final restored = store.openDraft(store.capture(UserRole.trainer));
      expect(restored.values, isEmpty);
      store.updateDraft(restored, 'name', 'Sign-out draft');
      await workspace.signIn(null);
      expect(restored.values, isEmpty);
    },
  );

  test('Only display identity from authenticated claims is attached to new records', () async {
    final workspace = _Workspace();
    addTearDown(workspace.roles.dispose);
    await workspace.seedRoles();
    final store = ReviewStore(
      roles: workspace.roles,
      currentUid: () => workspace.uid,
      firestore: workspace.firestore,
      accountClaims: () async => {
        'name': 'Account holder',
        'email': '${workspace.uid}@example.test',
        'phone': 'Do not export',
      },
    );
    await workspace.signIn('student');
    await store.apply(store.capture(UserRole.student), request);
    final application =
        (await workspace.firestore.doc('trainer_requests/student').get())
            .data()!;
    expect(application['accountName'], 'Account holder');
    expect(application['accountEmail'], 'student@example.test');
    expect(application.containsKey('phone'), isFalse);
    await workspace.signIn('trainer');
    final id = store.newSubmissionId();
    await store.submit(
      store.capture(UserRole.trainer),
      id,
      Technique.fromMap(id, technique),
    );
    final submission =
        (await store.watchSubmissions(owner: 'trainer').first).single;
    expect(submission.name, 'Account holder');
    expect(submission.email, 'trainer@example.test');
    expect(submission.submitterUid, 'trainer');
  });

  test(
    'Existing YouTube forms produce the ID and hostile hosts are rejected',
    () {
      for (final url in [
        'https://youtu.be/abcdefghijk?t=30',
        'https://www.youtube.com/watch?v=abcdefghijk',
        'https://m.youtube.com/watch?foo=bar&v=abcdefghijk',
        'https://youtube.com/shorts/abcdefghijk',
        'https://youtube.com/embed/abcdefghijk',
        'https://youtube.com/live/abcdefghijk',
      ]) {
        expect(Technique.youtubeId(url), 'abcdefghijk');
      }
      for (final url in [
        null,
        'https://youtube.com.example.test/watch?v=abcdefghijk',
        'ftp://youtu.be/abcdefghijk',
        'https://youtu.be/abc',
        'https://youtube.com/watch?video=abcdefghijk',
      ]) {
        expect(Technique.youtubeId(url), isNull);
      }
    },
  );

  test(
    'Application rejection, reapplication, grant and revocation persist',
    () async {
      final workspace = _Workspace();
      addTearDown(workspace.roles.dispose);
      final store = workspace.store;
      final application = workspace.firestore.doc('trainer_requests/student');
      Future<TrainerApplication> readRequest() async =>
          TrainerApplication(application.id, (await application.get()).data()!);
      await workspace.seedRoles();
      await workspace.signIn('student');
      final student = store.capture(UserRole.student);
      expect(await store.watchApplication('student').first, isNull);
      await store.apply(student, request);
      await expectLater(store.apply(student, request), throwsStateError);
      var entry = await readRequest();
      expect(entry.status, ReviewStatus.pending);
      expect(entry.data['requestedAt'], isNotNull);
      expect(entry.field('applicantUid'), 'student');

      await workspace.signIn('admin');
      final admin = store.capture(UserRole.administrator);
      expect(
        (await store.watchApplications().first).rows.single.uid,
        'student',
      );
      await expectLater(
        store.reviewApplication(admin, 'student', ReviewStatus.revoked),
        throwsStateError,
      );
      await store.reviewApplication(admin, 'student', ReviewStatus.rejected);
      entry = await readRequest();
      expect(entry.status, ReviewStatus.rejected);
      expect(entry.field('reviewerUid'), 'admin');
      expect(entry.data['reviewedAt'], isNotNull);

      await workspace.signIn('student');
      await expectLater(store.apply(student, request), throwsStateError);
      await store.apply(store.capture(UserRole.student), request);
      expect((await readRequest()).data.containsKey('reviewerUid'), isFalse);
      await workspace.signIn('admin');
      await store.reviewApplication(
        store.capture(UserRole.administrator),
        'student',
        ReviewStatus.approved,
      );
      await workspace.signIn('student');
      expect(store.capture(UserRole.trainer).uid, 'student');
      await workspace.signIn('admin');
      await store.reviewApplication(
        store.capture(UserRole.administrator),
        'student',
        ReviewStatus.revoked,
      );
      expect((await readRequest()).status, ReviewStatus.revoked);
      await workspace.signIn('student');
      await store.apply(store.capture(UserRole.student), request);
      expect((await readRequest()).status, ReviewStatus.pending);
    },
  );

  test('Submissions preserve ownership and atomically publish once', () async {
    final workspace = _Workspace();
    addTearDown(workspace.roles.dispose);
    final store = workspace.store;
    await workspace.seedRoles();
    await workspace.signIn('trainer');
    final trainer = store.capture(UserRole.trainer);
    final id = store.newSubmissionId();
    final rejected = store.newSubmissionId();
    final collision = store.newSubmissionId();
    for (final key in [id, rejected, collision]) {
      await store.submit(trainer, key, Technique.fromMap(key, technique));
    }
    expect(
      (await store.watchSubmissions(owner: 'someone-else').first),
      isEmpty,
    );
    final submissions = await store.watchSubmissions(owner: 'trainer').first;
    expect(
      submissions.map((row) => row.id),
      unorderedEquals([id, rejected, collision]),
    );
    expect(
      submissions.every(
        (row) =>
            row.submitterUid == 'trainer' && row.status == ReviewStatus.pending,
      ),
      isTrue,
    );
    expect((await store.watchTechniques().first).rows, isEmpty);

    await workspace.signIn('admin');
    final admin = store.capture(UserRole.administrator);
    await workspace.firestore.doc('techniques/$collision').set(technique);
    await expectLater(
      store.moderate(admin, collision, ReviewStatus.approved),
      throwsStateError,
    );
    await expectLater(
      store.moderate(admin, id, ReviewStatus.revoked),
      throwsArgumentError,
    );
    await store.moderate(admin, id, ReviewStatus.approved);
    await store.moderate(admin, id, ReviewStatus.approved);
    await store.moderate(admin, rejected, ReviewStatus.rejected);
    await expectLater(
      store.moderate(admin, rejected, ReviewStatus.approved),
      throwsStateError,
    );
    expect(
      (await workspace.firestore.doc('techniques/$id').get()).data(),
      technique,
    );
    expect(
      (await workspace.firestore.doc('techniques/$rejected').get()).exists,
      isFalse,
    );
    final row =
        (await workspace.firestore.doc('technique_submissions/$id').get())
            .data()!;
    expect(row['status'], 'approved');
    expect(row['submitterUid'], 'trainer');
    expect(row['reviewerUid'], 'admin');
    expect(row['reviewedAt'], isNotNull);
    await store.removeTechnique(admin, id);
    final removed =
        (await workspace.firestore.doc('technique_submissions/$id').get())
            .data()!;
    expect(removed['publicationState'], 'removed');
    expect(removed['publicationChangedBy'], 'admin');
    expect(removed['status'], 'approved');
    await store.moderate(admin, id, ReviewStatus.approved);
    expect(
      (await workspace.firestore.doc('techniques/$id').get()).exists,
      isFalse,
    );
    await store.republish(admin, id);
    expect(
      (await workspace.firestore.doc('techniques/$id').get()).data(),
      technique,
    );
    await expectLater(store.republish(admin, id), throwsStateError);
    await store.archiveSubmission(admin, id);
    await store.archiveSubmission(admin, id);
    expect(
      (await workspace.firestore.doc('techniques/$id').get()).exists,
      isTrue,
    );
    await store.removeTechnique(admin, id);
    await expectLater(store.republish(admin, id), throwsStateError);
    expect(
      (await workspace.firestore.doc('technique_submissions/$id').get())
          .data()?['archivedBy'],
      'admin',
    );
    await expectLater(
      store.archiveSubmission(admin, rejected),
      throwsStateError,
    );
    await expectLater(
      store.deleteRejectedSubmission(admin, id),
      throwsStateError,
    );
    await store.deleteRejectedSubmission(admin, rejected);
    expect(
      (await workspace.firestore.doc('technique_submissions/$rejected').get())
          .exists,
      isFalse,
    );
  });

  test(
    'Catalog edits preserve IDs and stale or revoked drafts cannot save',
    () async {
      final workspace = _Workspace();
      addTearDown(workspace.roles.dispose);
      final store = workspace.store;
      await workspace.seedRoles();
      await workspace.signIn('admin');
      final admin = store.capture(UserRole.administrator);
      final id = store.newTechniqueId();
      final original = Technique.fromMap(id, technique);
      await store.saveTechnique(admin, original, editing: false);
      await expectLater(
        store.saveTechnique(admin, original, editing: false),
        throwsStateError,
      );
      await store.saveTechnique(
        admin,
        Technique.fromMap(id, {...technique, 'name': 'Updated'}),
        editing: true,
      );
      expect((await store.watchTechniques().first).rows.single.id, id);
      expect((await store.watchTechniques().first).rows.single.name, 'Updated');

      await workspace.signIn('trainer');
      final trainer = store.capture(UserRole.trainer);
      await workspace.firestore.doc('user_roles/trainer').delete();
      await pumpEventQueue();
      expect(
        () => store.submit(trainer, store.newSubmissionId(), original),
        throwsStateError,
      );
      await workspace.firestore.doc('user_roles/trainer').set({
        'role': 'trainer',
      });
      await pumpEventQueue();
      expect(
        () => store.submit(trainer, store.newSubmissionId(), original),
        throwsStateError,
      );
      await workspace.signIn(null);
      expect(() => store.capture(UserRole.administrator), throwsStateError);
      await workspace.signIn('admin');
      expect(() => store.removeTechnique(admin, id), throwsStateError);
      await store.removeTechnique(store.capture(UserRole.administrator), id);
      await expectLater(
        store.saveTechnique(
          store.capture(UserRole.administrator),
          original,
          editing: true,
        ),
        throwsStateError,
      );
    },
  );
}
