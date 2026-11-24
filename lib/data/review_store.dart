import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/technique.dart';
import 'role_store.dart';

enum ReviewStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  revoked('Revoked');

  const ReviewStatus(this.label);
  final String label;

  static ReviewStatus? read(Object? value) =>
      values.where((status) => status.name == value).firstOrNull;
}

class TrainerApplication {
  const TrainerApplication(this.uid, this.data);

  static const positions = ['Instructor/Coach', 'Academy Owner', 'Dojo Staff'];

  final String uid;
  final Map<String, dynamic> data;
  ReviewStatus? get status => ReviewStatus.read(data['status']);
  String field(String key) => data[key]?.toString() ?? '';
  String get name =>
      _identityField(data, 'accountName') ??
      (data['academy'] == null ? 'Trainer account' : 'Trainer applicant');
  String get email => _identityField(data, 'accountEmail') ?? '';
  bool get external => data['external'] == true;
}

String? _identityField(Map<String, dynamic> data, String field) {
  final value = data[field];
  return value is String && value.trim().isNotEmpty ? value : null;
}

class TechniqueSubmission {
  TechniqueSubmission(this.id, Map<String, dynamic> data)
    : technique = Technique.fromMap(id, data),
      submitterUid = data['submitterUid'] as String,
      name = _identityField(data, 'accountName') ?? 'Trainer submitter',
      email = _identityField(data, 'accountEmail') ?? '',
      archived = data['archivedAt'] != null,
      submittedAt = (data['submittedAt'] as Timestamp?)?.toDate(),
      status = ReviewStatus.read(data['status']);

  final String id;
  final Technique technique;
  final String submitterUid;
  final String name;
  final String email;
  final bool archived;
  final DateTime? submittedAt;
  final ReviewStatus? status;
}

enum SubmissionFilter {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  removed('Removed');

  const SubmissionFilter(this.label);
  final String label;

  static SubmissionFilter? classify(
    TechniqueSubmission submission,
    Set<String> published,
  ) => switch (submission.status) {
    ReviewStatus.pending => pending,
    ReviewStatus.rejected => rejected,
    ReviewStatus.approved =>
      published.contains(submission.id) ? approved : removed,
    _ => null,
  };
}

typedef ReviewAccess = ({String uid, Object token, UserRole role});
typedef ReviewSnapshot<T> = ({List<T> rows, bool fromCache});

class SubmissionDraft extends ChangeNotifier {
  SubmissionDraft(this.access, this.id);

  final ReviewAccess access;
  final String id;
  final values = <String, String>{};
  bool _available = true;
  bool get available => _available;
  bool _saving = false;

  void _invalidate() {
    values.clear();
    _available = false;
    notifyListeners();
  }
}

class ReviewStore {
  ReviewStore({
    required this.roles,
    required this.currentUid,
    this.firestore,
    this.accountClaims,
  });

  final RoleStore roles;
  final String? Function() currentUid;
  final FirebaseFirestore? firestore;
  final Future<Map<String, dynamic>?> Function()? accountClaims;
  SubmissionDraft? _draft;
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('trainer_requests');
  CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection('technique_submissions');
  CollectionReference<Map<String, dynamic>> get _techniques =>
      _db.collection('techniques');

  ReviewAccess capture(UserRole role) {
    final uid = currentUid();
    if (uid == null || roles.verifiedRoleFor(uid) != role) {
      throw StateError('Your access has changed. Reopen this screen.');
    }
    return (uid: uid, token: roles.access, role: role);
  }

  void _check(ReviewAccess access, UserRole role) {
    if (capture(role) != access) {
      throw StateError('Your access has changed. Reopen this form.');
    }
  }

  Stream<TrainerApplication?> watchApplication(String uid) => _requests
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => doc.exists || !doc.metadata.isFromCache)
      .map((doc) {
        final data = doc.data();
        return data == null ? null : TrainerApplication(doc.id, data);
      });

  Stream<ReviewSnapshot<T>> _watch<T>(
    Query<Map<String, dynamic>> query,
    T Function(String id, Map<String, dynamic> data) decode,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => (
          rows: snapshot.docs.map((doc) => decode(doc.id, doc.data())).toList(),
          fromCache: snapshot.metadata.isFromCache,
        ),
      );

  Stream<ReviewSnapshot<TrainerApplication>> watchApplications() =>
      _watch(_requests, TrainerApplication.new);

  Stream<ReviewSnapshot<TrainerApplication>> watchTrainerRoles() => _watch(
    _db.collection('user_roles').where('role', isEqualTo: 'trainer'),
    (id, data) => TrainerApplication(id, {
      ...data,
      'status': 'approved',
      'external': true,
    }),
  );

  Stream<List<TechniqueSubmission>> watchSubmissions({String? owner}) {
    final query = owner == null
        ? _submissions
        : _submissions.where('submitterUid', isEqualTo: owner);
    return query.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          TechniqueSubmission(doc.id, doc.data()),
      ],
    );
  }

  Stream<ReviewSnapshot<TechniqueSubmission>> watchModeration() =>
      _watch(_submissions, TechniqueSubmission.new);

  Stream<ReviewSnapshot<Technique>> watchTechniques() =>
      _watch(_techniques, Technique.fromMap);

  Future<Map<String, String>> _identity() async {
    final claims = await accountClaims?.call();
    final result = <String, String>{};
    for (final (claim, field, limit) in [
      ('name', 'accountName', 120),
      ('email', 'accountEmail', 320),
    ]) {
      final value = claims?[claim];
      if (value is String && value.trim().isNotEmpty && value.length <= limit) {
        result[field] = value;
      }
    }
    return result;
  }

  Future<void> apply(
    ReviewAccess access,
    Map<String, String> values, {
    TrainerApplication? editing,
  }) async {
    _check(access, UserRole.student);
    final identity = editing == null
        ? await _identity()
        : const <String, String>{};
    await _db.runTransaction((transaction) async {
      _check(access, UserRole.student);
      final ref = _requests.doc(access.uid);
      final current = await transaction.get(ref);
      final data = current.data();
      final status = ReviewStatus.read(data?['status']);
      _check(access, UserRole.student);
      if (editing != null) {
        if (status != ReviewStatus.pending ||
            editing.uid != access.uid ||
            data?['requestedAt'] != editing.data['requestedAt'] ||
            data?['updatedAt'] != editing.data['updatedAt']) {
          throw StateError('This request has changed. Reopen it from Profile.');
        }
        transaction.update(ref, {
          ...values,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      if (current.exists &&
          status != ReviewStatus.rejected &&
          status != ReviewStatus.revoked) {
        throw StateError('You already have an active request.');
      }
      transaction.set(ref, {
        ...values,
        ...identity,
        'applicantUid': access.uid,
        'status': ReviewStatus.pending.name,
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, Object> _decision(ReviewAccess access, ReviewStatus status) => {
    'status': status.name,
    'reviewerUid': access.uid,
    'reviewedAt': FieldValue.serverTimestamp(),
  };

  Future<void> reviewApplication(
    ReviewAccess access,
    String uid,
    ReviewStatus decision, {
    String? reason,
    TrainerApplication? external,
  }) => _db.runTransaction((transaction) async {
    _check(access, UserRole.administrator);
    final ref = _requests.doc(uid);
    final role = _db.collection('user_roles').doc(uid);
    final snapshot = await transaction.get(ref);
    final previous = ReviewStatus.read(snapshot.data()?['status']);
    final valid = switch (decision) {
      ReviewStatus.revoked =>
        external != null
            ? external.external && external.uid == uid && !snapshot.exists
            : previous == ReviewStatus.approved,
      ReviewStatus.approved =>
        previous == ReviewStatus.pending || previous == ReviewStatus.revoked,
      ReviewStatus.rejected => previous == ReviewStatus.pending,
      ReviewStatus.pending => false,
    };
    if (!valid) {
      throw StateError('This request has already changed.');
    }
    _check(access, UserRole.administrator);
    final decisionData = _decision(access, decision);
    final note = reason?.trim() ?? '';
    if (note.isNotEmpty) decisionData['reviewReason'] = note;
    if (external != null) {
      transaction.set(ref, {
        ...decisionData,
        'applicantUid': uid,
        for (final field in ['accountName', 'accountEmail'])
          field: ?external.data[field],
      });
    } else {
      transaction.update(ref, {
        ...decisionData,
        if (note.isEmpty) 'reviewReason': FieldValue.delete(),
      });
    }
    if (decision == ReviewStatus.approved) {
      transaction.set(role, {'role': 'trainer'});
    } else if (decision == ReviewStatus.revoked) {
      transaction.delete(role);
    }
  });

  String newSubmissionId() => 'submission_${_submissions.doc().id}';

  SubmissionDraft openDraft(ReviewAccess access) {
    _check(access, UserRole.trainer);
    final existing = _draft;
    if (existing?.access == access) return existing!;
    final draft = SubmissionDraft(access, newSubmissionId());
    _draft = draft;
    if (existing == null) roles.addListener(_checkDraft);
    return draft;
  }

  void _checkDraft() {
    final draft = _draft!;
    if (draft.access.token != roles.access ||
        draft.access.uid != currentUid()) {
      clearDraft(draft);
    }
  }

  void clearDraft(SubmissionDraft draft) {
    if (_draft != draft) return;
    _draft = null;
    roles.removeListener(_checkDraft);
    draft._invalidate();
  }

  void updateDraft(SubmissionDraft draft, String field, String value) {
    if (_draft == draft) draft.values[field] = value;
  }

  Future<void> submitDraft(SubmissionDraft draft, Technique technique) async {
    if (_draft != draft || draft._saving) {
      throw StateError(
        'This draft is no longer available or is already saving.',
      );
    }
    draft._saving = true;
    try {
      await submit(draft.access, draft.id, technique);
      clearDraft(draft);
    } finally {
      draft._saving = false;
    }
  }

  Future<void> submit(
    ReviewAccess access,
    String id,
    Technique technique,
  ) async {
    _check(access, UserRole.trainer);
    final identity = await _identity();
    _check(access, UserRole.trainer);
    await _submissions.doc(id).set({
      ...technique.toPublication(),
      ...identity,
      'submitterUid': access.uid,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': ReviewStatus.pending.name,
    });
  }

  Future<void> moderate(
    ReviewAccess access,
    String id,
    ReviewStatus decision,
  ) => _db.runTransaction((transaction) async {
    _check(access, UserRole.administrator);
    final ref = _submissions.doc(id);
    final snapshot = await transaction.get(ref);
    final status = ReviewStatus.read(snapshot.data()?['status']);
    if (decision == ReviewStatus.revoked) {
      throw ArgumentError.value(decision, 'decision');
    }
    if (status == decision) return;
    if (status !=
        (decision == ReviewStatus.pending
            ? ReviewStatus.rejected
            : ReviewStatus.pending)) {
      throw StateError('This submission has already changed.');
    }
    final publication = _techniques.doc(id);
    if (decision != ReviewStatus.rejected) {
      final existing = await transaction.get(publication);
      if (existing.exists) throw StateError('This technique ID is in use.');
    }
    _check(access, UserRole.administrator);
    if (decision == ReviewStatus.approved) {
      transaction.set(
        publication,
        Technique.fromMap(id, snapshot.data()!).toPublication(),
      );
    }
    transaction.update(ref, {
      ..._decision(access, decision),
      if (decision == ReviewStatus.approved) 'publicationState': 'published',
    });
  });

  Future<void> deleteApplication(ReviewAccess access, String uid) =>
      _db.runTransaction((transaction) async {
        _check(access, UserRole.administrator);
        final ref = _requests.doc(uid);
        final status = ReviewStatus.read(
          (await transaction.get(ref)).data()?['status'],
        );
        if (status != ReviewStatus.rejected && status != ReviewStatus.revoked) {
          throw StateError(
            'Only rejected and revoked applications can be deleted.',
          );
        }
        _check(access, UserRole.administrator);
        // The Rules check that no authorization document is present. Direct
        // reads of another user's authorization document remain restricted.
        transaction.delete(ref);
      });

  Future<void> deleteRejectedSubmission(ReviewAccess access, String id) =>
      _db.runTransaction((transaction) async {
        _check(access, UserRole.administrator);
        final ref = _submissions.doc(id);
        final data = (await transaction.get(ref)).data();
        if (data?['status'] != ReviewStatus.rejected.name ||
            (await transaction.get(_techniques.doc(id))).exists) {
          throw StateError(
            'Only unpublished rejected submissions can be deleted.',
          );
        }
        _check(access, UserRole.administrator);
        transaction.delete(ref);
      });

  Future<void> archiveSubmission(ReviewAccess access, String id) =>
      _db.runTransaction((transaction) async {
        _check(access, UserRole.administrator);
        final ref = _submissions.doc(id);
        final data = (await transaction.get(ref)).data();
        if (data?['status'] != ReviewStatus.approved.name) {
          throw StateError('Only approved review records can be archived.');
        }
        _check(access, UserRole.administrator);
        if (data?['archivedAt'] != null) return;
        transaction.update(ref, {
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': access.uid,
        });
      });

  Map<String, Object> _publicationChange(ReviewAccess access, String state) => {
    'publicationState': state,
    'publicationChangedAt': FieldValue.serverTimestamp(),
    'publicationChangedBy': access.uid,
  };

  Future<void> republish(ReviewAccess access, String id) => _db.runTransaction((
    transaction,
  ) async {
    _check(access, UserRole.administrator);
    final ref = _submissions.doc(id);
    final publication = _techniques.doc(id);
    final data = (await transaction.get(ref)).data();
    if (!_linkedId.hasMatch(id) ||
        data == null ||
        data['status'] != ReviewStatus.approved.name ||
        data['archivedAt'] != null) {
      throw StateError('This review record cannot be republished.');
    }
    if ((await transaction.get(publication)).exists) {
      throw StateError('A technique with this ID is already in the library.');
    }
    _check(access, UserRole.administrator);
    transaction.set(publication, Technique.fromMap(id, data).toPublication());
    transaction.update(ref, _publicationChange(access, 'published'));
  });

  String newTechniqueId() => _techniques.doc().id;

  Future<void> saveTechnique(
    ReviewAccess access,
    Technique technique, {
    required bool editing,
  }) => _db.runTransaction((transaction) async {
    _check(access, UserRole.administrator);
    final ref = _techniques.doc(technique.id);
    final exists = (await transaction.get(ref)).exists;
    if (exists != editing) throw StateError('This technique has changed.');
    _check(access, UserRole.administrator);
    transaction.set(ref, technique.toPublication());
  });

  static final _linkedId = RegExp(r'^submission_[A-Za-z0-9]{20}$');

  Future<void> removeTechnique(ReviewAccess access, String id) =>
      _db.runTransaction((transaction) async {
        _check(access, UserRole.administrator);
        final publication = _techniques.doc(id);
        if (!(await transaction.get(publication)).exists) return;
        final review = _submissions.doc(id);
        final linked =
            _linkedId.hasMatch(id) &&
            (await transaction.get(review)).data()?['status'] ==
                ReviewStatus.approved.name;
        _check(access, UserRole.administrator);
        if (linked) {
          transaction.update(review, _publicationChange(access, 'removed'));
        }
        transaction.delete(publication);
      });
}
