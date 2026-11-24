import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';

const project = 'demo-bjj-110';
const run = randomUUID();

function emulator(name) {
  const host = process.env[name];
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host ?? '')) {
    throw new Error(`Run with firebase emulators:exec for ${project}; ${name} must be loopback.`);
  }
  return `http://${host}`;
}

const auth = emulator('FIREBASE_AUTH_EMULATOR_HOST');
const firestore = emulator('FIRESTORE_EMULATOR_HOST');
const documents = `${firestore}/v1/projects/${project}/databases/(default)/documents`;
const fixtures = new Set();

async function account(name) {
  const response = await fetch(
    `${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `${name}-${run}@example.test`,
        displayName: name,
        password: 'local-test-password',
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return { uid: body.localId, token: body.idToken, email: body.email, name };
}

async function expectStatus(status, path, { token, method = 'GET', data } = {}) {
  if (method === 'PATCH') fixtures.add(path);
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (data) headers['Content-Type'] = 'application/json';
  const body = data && JSON.stringify({
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, { stringValue: value }]),
    ),
  });
  const response = await fetch(`${documents}/${path}`, { method, headers, body });
  const result = await response.text();
  assert.equal(response.status, status, `${method} ${path}: ${result}`);
}

let student;
let trainer;
let admin;
let personal;
const technique = `techniques/${run}`;

before(async () => {
  [student, trainer, admin] = await Promise.all(
    ['student', 'trainer', 'admin'].map(account),
  );
  personal = `users/${student.uid}/settings/profile`;
  // The emulator-only owner token is used only for fixture setup.
  for (const [path, data] of [
    [`user_roles/${trainer.uid}`, { role: 'trainer' }],
    [`user_roles/${admin.uid}`, { role: 'admin' }],
    [personal, { name: 'Student' }],
    [technique, { category: 'Guards', description: 'Example', difficulty: 'Beginner',
      instructor: 'Coach', name: 'Armbar', videoUrl: 'https://youtu.be/abcdefghijk' }],
  ]) {
    await expectStatus(200, path, { token: 'owner', method: 'PATCH', data });
  }
});

test('Owner can read, list, write and delete their personal documents', async () => {
  const token = student.token;
  await expectStatus(200, personal, { token });
  await expectStatus(200, `users/${student.uid}/settings`, { token });
  const entry = `users/${student.uid}/sessions/${run}`;
  await expectStatus(200, entry, { token, method: 'PATCH', data: { type: 'Class' } });
  await expectStatus(200, entry, { token, method: 'DELETE' });
});

test('Other users, including administrators, cannot access personal data', async () => {
  for (const { token } of [trainer, admin]) {
    await expectStatus(403, personal, { token });
    await expectStatus(403, `users/${student.uid}/settings`, { token });
    await expectStatus(403, personal, { token, method: 'PATCH', data: { name: 'Other' } });
    await expectStatus(403, personal, { token, method: 'DELETE' });
  }
});

test('Users can get their own role, including a missing Student document', async () => {
  await expectStatus(404, `user_roles/${student.uid}`, { token: student.token });
  for (const { uid, token } of [trainer, admin]) {
    await expectStatus(200, `user_roles/${uid}`, { token });
  }
});

test('Other role documents and collection listing are denied', async () => {
  await expectStatus(403, `user_roles/${admin.uid}`, { token: student.token });
  await expectStatus(403, `user_roles/${trainer.uid}`, { token: admin.token });
  await expectStatus(403, 'user_roles', { token: admin.token });
});

test('Standalone role writes and Administrator grants are denied', async () => {
  for (const { token } of [student, trainer, admin]) {
    for (const uid of [student.uid, trainer.uid, admin.uid]) {
      const path = `user_roles/${uid}`;
      await expectStatus(403, path, { token, method: 'PATCH', data: { role: 'admin' } });
      await expectStatus(403, path, { token, method: 'DELETE' });
    }
  }
});

test('Techniques are readable by signed-in users and only administrators may write', async () => {
  for (const { token } of [student, trainer, admin]) {
    await expectStatus(200, technique, { token });
    await expectStatus(200, 'techniques', { token });
  }
  for (const { token } of [student, trainer]) {
    for (const path of [technique, `techniques/new-${run}`]) {
      await expectStatus(403, path, { token, method: 'PATCH', data: { name: 'Changed' } });
    }
    await expectStatus(403, technique, { token, method: 'DELETE' });
  }
});

test('Signed-out reads and writes are denied', async () => {
  for (const path of [personal, technique, `user_roles/${admin.uid}`]) {
    await expectStatus(403, path);
    await expectStatus(403, path, { method: 'PATCH', data: { role: 'admin' } });
    await expectStatus(403, path, { method: 'DELETE' });
  }
});

test('Incomplete requests and submissions are denied for every role', async () => {
  for (const { uid, token } of [student, trainer, admin]) {
    for (const path of [`trainer_requests/${uid}`, `technique_submissions/${run}`]) {
      await expectStatus(403, path, { token, method: 'PATCH', data: { status: 'pending' } });
    }
  }
});

const name = (path) => `projects/${project}/databases/(default)/documents/${path}`;
const values = (data) => Object.fromEntries(
  Object.entries(data).map(([key, value]) => [key, { stringValue: value }]),
);
const write = (path, data, timestamp, partial = false) => {
  fixtures.add(path);
  return {
    update: { name: name(path), fields: values(data) },
    ...(partial ? { updateMask: { fieldPaths: Object.keys(data) } } : {}),
    ...(timestamp ? { updateTransforms: [{ fieldPath: timestamp, setToServerValue: 'REQUEST_TIME' }] } : {}),
  };
};
const remove = (path) => ({ delete: name(path) });
async function commit(status, token, ...writes) {
  const response = await fetch(`${documents}:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ writes }),
  });
  const result = await response.text();
  assert.equal(response.status, status, result);
}
after(async () => {
  if (fixtures.size) await commit(200, 'owner', ...[...fixtures].map(remove));
});

const application = (uid) => ({
  applicantUid: uid, academy: 'Demo Academy', position: 'Instructor/Coach',
  belt: '', contact: 'coach@example.test', reason: 'I teach classes.', status: 'pending',
});
const review = (path, status, reviewer = admin.uid) =>
  write(path, {
    status, reviewerUid: reviewer,
    ...(path.startsWith('technique_submissions/') && status === 'approved'
      ? { publicationState: 'published' } : {}),
  }, 'reviewedAt', true);
const publicationChange = (path, publicationState, reviewer = admin.uid) =>
  write(path, { publicationState, publicationChangedBy: reviewer }, 'publicationChangedAt', true);
const archive = (path, reviewer = admin.uid) =>
  write(path, { archivedBy: reviewer }, 'archivedAt', true);
const publication = {
  name: 'Emulator technique', category: 'Guard', description: 'Practice safely.',
  instructor: 'Coach', difficulty: 'Intermediate', videoUrl: 'https://youtu.be/abcdefghijk',
};
const submission = (uid) => ({ ...publication, status: 'pending', submitterUid: uid });
const submissionId = () => `submission_${randomUUID().replaceAll('-', '').slice(0, 20)}`;

test('Trainer review keeps requests and grants atomic, including reapplication and revocation', async () => {
  const applicant = await account('applicant');
  const path = `trainer_requests/${applicant.uid}`;
  const role = `user_roles/${applicant.uid}`;
  const apply = write(path, application(applicant.uid), 'requestedAt');
  await commit(403, applicant.token, write(path, application(student.uid), 'requestedAt'));
  await commit(403, applicant.token, write(path, { ...application(applicant.uid), academy: '   ' }, 'requestedAt'));
  await commit(403, applicant.token, write(path, { ...application(applicant.uid), status: 'approved' }, 'requestedAt'));
  await commit(200, applicant.token, apply);
  await commit(403, applicant.token, apply);
  await expectStatus(200, path, { token: applicant.token });
  await expectStatus(403, path, { token: trainer.token });
  await expectStatus(200, 'trainer_requests', { token: admin.token });
  await commit(403, applicant.token, review(path, 'approved', applicant.uid));
  await commit(403, admin.token, review(path, 'approved'));
  await commit(403, admin.token, write(role, { role: 'trainer' }));
  await commit(403, admin.token, review(path, 'rejected', trainer.uid));
  await commit(200, admin.token, review(path, 'rejected'));
  await commit(200, applicant.token, apply);
  await commit(403, admin.token, review(path, 'approved'), write(role, { role: 'admin' }));
  await commit(200, admin.token, review(path, 'approved'), write(role, { role: 'trainer' }));
  await expectStatus(200, role, { token: applicant.token });
  const submissionPath = `technique_submissions/${submissionId()}`;
  await commit(200, applicant.token, write(submissionPath, submission(applicant.uid), 'submittedAt'));
  await commit(403, applicant.token, apply);
  await commit(403, admin.token, review(path, 'revoked'));
  await commit(403, admin.token, remove(role));
  await commit(200, admin.token, review(path, 'revoked'), remove(role));
  await expectStatus(404, role, { token: applicant.token });
  await expectStatus(403, submissionPath, { token: applicant.token });
  await commit(403, applicant.token, write(`technique_submissions/${submissionId()}`, submission(applicant.uid), 'submittedAt'));
  await commit(200, applicant.token, apply);
});

test('Trainer management cannot replace, revoke, or create an Administrator role', async () => {
  const otherAdmin = await account('other-admin');
  const path = `trainer_requests/${otherAdmin.uid}`;
  const role = `user_roles/${otherAdmin.uid}`;
  await commit(200, 'owner', write(role, { role: 'admin' }), write(path, application(otherAdmin.uid), 'requestedAt'));
  await commit(403, admin.token, review(path, 'approved'), write(role, { role: 'trainer' }));
  await commit(200, 'owner', review(path, 'approved'));
  await commit(403, admin.token, review(path, 'revoked'), remove(role));
});

test('Submission ownership, URL validation, and atomic publication are enforced', async () => {
  const id = submissionId();
  const path = `technique_submissions/${id}`;
  const published = `techniques/${id}`;
  await commit(403, student.token, write(path, submission(student.uid), 'submittedAt'));
  await commit(403, trainer.token, write(path, submission(student.uid), 'submittedAt'));
  await commit(403, trainer.token, write(path, { ...submission(trainer.uid), videoUrl: 'https://youtube.com.evil.test/watch?v=abcdefghijk' }, 'submittedAt'));
  await commit(200, trainer.token, write(path, submission(trainer.uid), 'submittedAt'));
  await expectStatus(200, path, { token: trainer.token });
  await expectStatus(403, path, { token: student.token });
  await expectStatus(403, 'technique_submissions', { token: trainer.token });
  const query = await fetch(`${documents}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${trainer.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId: 'technique_submissions' }],
      where: { fieldFilter: {
        field: { fieldPath: 'submitterUid' }, op: 'EQUAL',
        value: { stringValue: trainer.uid },
      } },
    } }),
  });
  const own = await query.json();
  assert.equal(query.status, 200, JSON.stringify(own));
  assert.ok(own.some((result) => result.document?.name === name(path)));
  await expectStatus(200, 'technique_submissions', { token: admin.token });
  await expectStatus(404, published, { token: student.token });
  await commit(403, trainer.token, review(path, 'approved', trainer.uid), write(published, publication));
  await commit(403, admin.token, review(path, 'approved'));
  await commit(403, admin.token, write(published, publication));
  await commit(403, admin.token, review(path, 'approved'), write(published, { ...publication, name: 'Forged' }));
  await commit(200, admin.token, review(path, 'approved'), write(published, publication));
  await expectStatus(200, published, { token: student.token });
  await commit(403, admin.token, review(path, 'approved'), write(published, publication));
  await commit(403, admin.token, review(path, 'pending'));
  await commit(403, admin.token, remove(published));
  await commit(200, admin.token, remove(published), publicationChange(path, 'removed'));
  await commit(403, admin.token, write(published, publication));
});

test('Rejection stays private and direct administrator catalog CRUD is validated', async () => {
  const id = submissionId();
  const path = `technique_submissions/${id}`;
  const direct = `techniques/direct-${run}`;
  await commit(200, trainer.token, write(path, submission(trainer.uid), 'submittedAt'));
  await commit(200, admin.token, review(path, 'rejected'));
  await expectStatus(404, `techniques/${id}`, { token: student.token });
  await commit(403, admin.token, review(path, 'approved'), write(`techniques/${id}`, publication));
  await commit(403, trainer.token, write(direct, publication));
  await commit(403, admin.token, write(direct, { ...publication, difficulty: 'Expert' }));
  await commit(200, admin.token, write(direct, publication));
  await commit(200, admin.token, write(direct, { ...publication, name: 'Edited' }));
  await commit(200, admin.token, remove(direct));
  await expectStatus(404, direct, { token: trainer.token });
});

test('Only the applicant can edit pending fields and identity matches Auth', async () => {
  const applicant = await account('editor');
  const path = `trainer_requests/${applicant.uid}`;
  const valid = { ...application(applicant.uid), accountName: applicant.name, accountEmail: applicant.email };
  await commit(403, applicant.token, write(path, { ...valid, accountEmail: admin.email }, 'requestedAt'));
  await commit(403, applicant.token, write(path, { ...valid, accountName: 'Forged' }, 'requestedAt'));
  await commit(200, applicant.token, write(path, valid, 'requestedAt'));
  const edit = write(path, { academy: 'Edited academy' }, 'updatedAt', true);
  await commit(200, applicant.token, edit);
  await expectStatus(200, path, { token: applicant.token });
  await commit(403, student.token, edit);
  await commit(403, admin.token, edit);
  for (const change of [
    { applicantUid: trainer.uid }, { reviewerUid: admin.uid }, { status: 'approved' },
    { accountName: 'Forged edit' }, { reviewReason: 'Forged reason' },
  ]) {
    await commit(403, applicant.token, write(path, change, 'updatedAt', true));
  }
  await commit(403, applicant.token, write(path, { academy: 'Bad original timestamp' }, 'requestedAt', true));
  await commit(200, admin.token, write(path, {
    status: 'rejected', reviewerUid: admin.uid, reviewReason: 'Please add contact details.',
  }, 'reviewedAt', true));
  await expectStatus(200, path, { token: applicant.token });
  await commit(403, applicant.token, edit);
});

test('Rejected submissions may be reopened only by administrators and reviewed again', async () => {
  const id = submissionId();
  const path = `technique_submissions/${id}`;
  const techniquePath = `techniques/${id}`;
  const valid = { ...submission(trainer.uid), accountEmail: trainer.email, accountName: trainer.name };
  await commit(403, trainer.token, write(path, { ...valid, accountName: admin.name }, 'submittedAt'));
  await commit(200, trainer.token, write(path, valid, 'submittedAt'));
  await commit(200, admin.token, review(path, 'rejected'));
  await commit(403, trainer.token, review(path, 'pending', trainer.uid));
  await commit(403, admin.token, write(path, {
    status: 'pending', reviewerUid: admin.uid, submitterUid: admin.uid,
  }, 'reviewedAt', true));
  await commit(200, admin.token, review(path, 'pending'));
  await expectStatus(404, techniquePath, { token: trainer.token });
  await commit(200, admin.token, review(path, 'approved'), write(techniquePath, publication));
  await commit(403, admin.token, review(path, 'pending'));
});

test('Administrators can manage a direct Trainer grant and reinstate only atomically', async () => {
  const user = await account('external');
  const role = `user_roles/${user.uid}`;
  const path = `trainer_requests/${user.uid}`;
  const revocation = write(path, {
    status: 'revoked', applicantUid: user.uid, reviewerUid: admin.uid, reviewReason: 'No longer coaching.',
  }, 'reviewedAt');
  const reinstatement = review(path, 'approved');
  await commit(200, 'owner', write(role, { role: 'trainer' }));
  const queryBody = JSON.stringify({ structuredQuery: {
    from: [{ collectionId: 'user_roles' }],
    where: { fieldFilter: {
      field: { fieldPath: 'role' }, op: 'EQUAL', value: { stringValue: 'trainer' },
    } },
  } });
  for (const [actor, expected] of [[admin, 200], [trainer, 403]]) {
    const response = await fetch(`${documents}:runQuery`, {
      method: 'POST', headers: { Authorization: `Bearer ${actor.token}`, 'Content-Type': 'application/json' },
      body: queryBody,
    });
    const result = await response.json();
    assert.equal(response.status, expected, JSON.stringify(result));
    if (expected === 200) assert.ok(result.some((item) => item.document?.name === name(role)));
  }
  await commit(403, admin.token, remove(role));
  await commit(403, admin.token, revocation);
  await commit(200, admin.token, revocation, remove(role));
  await expectStatus(200, path, { token: user.token });
  await commit(403, user.token, reinstatement, write(role, { role: 'trainer' }));
  await commit(403, admin.token, write(role, { role: 'trainer' }));
  await commit(403, admin.token, reinstatement);
  // Reinstatement removes the old reason to keep the decision consistent.
  const approved = { ...reinstatement, updateMask: { fieldPaths: ['status', 'reviewerUid', 'reviewReason'] } };
  await commit(403, admin.token, approved, write(role, { role: 'admin' }));
  await commit(200, admin.token, approved, write(role, { role: 'trainer' }));
  await expectStatus(200, role, { token: user.token });
});

test('Only administrators can delete inactive reviewed trainer applications', async () => {
  const applicant = await account('cleanup');
  const path = `trainer_requests/${applicant.uid}`;
  const role = `user_roles/${applicant.uid}`;
  const apply = write(path, application(applicant.uid), 'requestedAt');
  await commit(200, applicant.token, apply);
  await commit(403, admin.token, remove(path));
  await commit(200, admin.token, review(path, 'rejected'));
  for (const { token } of [student, trainer, applicant]) {
    await commit(403, token, remove(path));
  }
  await commit(200, admin.token, remove(path));
  await expectStatus(404, path, { token: applicant.token });
  await commit(200, applicant.token, apply);
  await commit(200, admin.token, review(path, 'approved'), write(role, { role: 'trainer' }));
  await commit(403, admin.token, remove(path));
  await commit(403, admin.token, remove(path), remove(role));
  await commit(200, admin.token, review(path, 'revoked'), remove(role));
  // Trusted provisioning can create a role separately; cleanup cannot orphan it.
  await commit(200, 'owner', write(role, { role: 'trainer' }));
  await commit(403, admin.token, remove(path));
  await commit(200, 'owner', remove(role));
  await commit(200, admin.token, remove(path));
  await commit(403, admin.token, review(path, 'approved'), write(role, { role: 'trainer' }));
});

test('Linked removal and republication are atomic and approval remains intact', async () => {
  const id = submissionId();
  const path = `technique_submissions/${id}`;
  const published = `techniques/${id}`;
  await commit(200, trainer.token, write(path, submission(trainer.uid), 'submittedAt'));
  await commit(200, admin.token, review(path, 'approved'), write(published, publication));
  await commit(403, admin.token, remove(published));
  await commit(403, admin.token, publicationChange(path, 'removed'));
  await commit(403, trainer.token, remove(published), publicationChange(path, 'removed', trainer.uid));
  await commit(200, admin.token, remove(published), publicationChange(path, 'removed'));
  await expectStatus(404, published, { token: student.token });
  await expectStatus(200, path, { token: trainer.token });
  await commit(403, admin.token, publicationChange(path, 'published'));
  await commit(403, admin.token, write(published, publication));
  await commit(403, admin.token, publicationChange(path, 'published'), write(published, { ...publication, name: 'Forged' }));
  await commit(200, admin.token, publicationChange(path, 'published'), write(published, publication));
  await commit(403, admin.token, publicationChange(path, 'published'), write(published, publication));
  await expectStatus(200, published, { token: student.token });
  await commit(403, admin.token, review(path, 'pending'));
});

test('Rejected video deletion and review archival preserve catalog records', async () => {
  const id = submissionId();
  const path = `technique_submissions/${id}`;
  const approvedId = submissionId();
  const approved = `technique_submissions/${approvedId}`;
  const published = `techniques/${approvedId}`;
  await commit(200, trainer.token, write(path, submission(trainer.uid), 'submittedAt'));
  await commit(403, admin.token, remove(path));
  await commit(403, admin.token, archive(path));
  await commit(200, admin.token, review(path, 'rejected'));
  await commit(403, trainer.token, remove(path));
  await commit(403, admin.token, archive(path));
  await commit(200, admin.token, remove(path));
  await expectStatus(404, `techniques/${id}`, { token: student.token });
  await commit(200, trainer.token, write(approved, submission(trainer.uid), 'submittedAt'));
  await commit(200, admin.token, review(approved, 'approved'), write(published, publication));
  await commit(403, student.token, archive(approved, student.uid));
  await commit(403, trainer.token, archive(approved, trainer.uid));
  await commit(403, admin.token, archive(approved, trainer.uid));
  await commit(403, admin.token, remove(approved));
  await commit(403, admin.token, archive(approved), remove(published));
  await commit(200, admin.token, archive(approved));
  await expectStatus(200, published, { token: student.token });
  await commit(200, admin.token, publicationChange(approved, 'removed'), remove(published));
  await commit(403, admin.token, publicationChange(approved, 'published'), write(published, publication));
});

test('A legacy approved submission missing its catalog document can be restored or archived', async () => {
  const legacy = submissionId();
  const archivedLegacy = submissionId();
  for (const id of [legacy, archivedLegacy]) {
    await commit(200, 'owner', write(`technique_submissions/${id}`, {
      ...submission(trainer.uid), status: 'approved',
    }, 'submittedAt'));
  }
  await commit(200, admin.token,
    publicationChange(`technique_submissions/${legacy}`, 'published'),
    write(`techniques/${legacy}`, publication));
  await commit(200, admin.token, archive(`technique_submissions/${archivedLegacy}`));
  await expectStatus(404, `techniques/${archivedLegacy}`, { token: student.token });
});
