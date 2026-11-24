import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { before, test } from 'node:test';

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

async function account(name) {
  const response = await fetch(
    `${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `${name}-${run}@example.test`,
        password: 'local-test-password',
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return { uid: body.localId, token: body.idToken };
}

async function expectStatus(status, path, { token, method = 'GET', data } = {}) {
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

test('All role writes are denied, including self-promotion and administrator writes', async () => {
  for (const { token } of [student, trainer, admin]) {
    for (const uid of [student.uid, trainer.uid, admin.uid]) {
      const path = `user_roles/${uid}`;
      await expectStatus(403, path, { token, method: 'PATCH', data: { role: 'admin' } });
      await expectStatus(403, path, { token, method: 'DELETE' });
    }
  }
});

test('Techniques are readable by signed-in users and all client writes are denied', async () => {
  for (const { token } of [student, trainer, admin]) {
    await expectStatus(200, technique, { token });
    await expectStatus(200, 'techniques', { token });
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

test('Phase 2 request and submission collection writes are denied', async () => {
  for (const { uid, token } of [student, trainer, admin]) {
    for (const path of [`trainer_requests/${uid}`, `technique_submissions/${run}`]) {
      await expectStatus(403, path, { token, method: 'PATCH', data: { status: 'pending' } });
    }
  }
});
