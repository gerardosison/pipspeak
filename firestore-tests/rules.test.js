import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pipspeak',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice', { email: 'a@x.com' }).firestore();
const bob = () => env.authenticatedContext('bob', { email: 'b@x.com' }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const profile = () => ({
  fullName: 'Alice A',
  nickname: 'Alice',
  username: 'alice',
  language: 'English (US)',
  practicePurpose: 'Debate',
  school: '',
  onboardingComplete: true,
  revision: 'r1',
  updatedAt: serverTimestamp(),
});

const completedAt = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
const session = (uid = 'alice') => ({
  userId: uid,
  completedAt,
  practicePurpose: 'presentation',
  language: 'en-US',
  durationSeconds: 60,
  starsEarned: 1,
  baselineSessionId: 'base',
  scoringVersion: 'v1',
  isTest: false,
  overallScore: 72.5,
  wordsPerMinute: 140,
  fillerCount: 3,
});

test('owner can write and read own profile', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), profile()));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
});

test('other users and anonymous cannot read or write a profile', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), profile()));
  await assertFails(getDoc(doc(bob(), 'users/alice')));
  await assertFails(getDoc(doc(anon(), 'users/alice')));
  await assertFails(setDoc(doc(bob(), 'users/alice'), profile()));
});

test('profile rejects extra fields, bad types and client timestamps', async () => {
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...profile(), admin: true }));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...profile(), fullName: 5 }));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...profile(), updatedAt: completedAt }));
});

test('owner can create a session and retry identically', async () => {
  const ref = doc(alice(), 'users/alice/sessions/s1');
  await assertSucceeds(setDoc(ref, session()));
  await assertSucceeds(setDoc(ref, session()));
  await assertSucceeds(getDoc(ref));
});

test('completed sessions are immutable', async () => {
  const ref = doc(alice(), 'users/alice/sessions/s1');
  await assertSucceeds(setDoc(ref, session()));
  await assertFails(setDoc(ref, { ...session(), starsEarned: 3 }));
});

test('session validation rejects wrong owner, extra fields and bad values', async () => {
  const ref = doc(alice(), 'users/alice/sessions/s2');
  await assertFails(setDoc(ref, session('bob')));
  await assertFails(setDoc(ref, { ...session(), transcript: 'raw text' }));
  await assertFails(setDoc(ref, { ...session(), starsEarned: 4 }));
  await assertFails(setDoc(ref, { ...session(), durationSeconds: -1 }));
  await assertFails(setDoc(ref, { ...session(), overallScore: 101 }));
});

test('non-owner and anonymous cannot access sessions', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/sessions/s1'), session()));
  await assertFails(getDoc(doc(bob(), 'users/alice/sessions/s1')));
  await assertFails(getDoc(doc(anon(), 'users/alice/sessions/s1')));
  await assertFails(setDoc(doc(bob(), 'users/alice/sessions/s9'), session('alice')));
});

test('usernames: claim own, no hijack, public get', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'usernames/alice'), { uid: 'alice' }));
  await assertFails(setDoc(doc(bob(), 'usernames/alice'), { uid: 'bob' }));
  await assertFails(setDoc(doc(bob(), 'usernames/bobby'), { uid: 'alice' }));
  await assertFails(setDoc(doc(bob(), 'usernames/Bad Name'), { uid: 'bob' }));
  await assertSucceeds(getDoc(doc(anon(), 'usernames/alice')));
  await assertFails(deleteDoc(doc(bob(), 'usernames/alice')));
  await assertSucceeds(deleteDoc(doc(alice(), 'usernames/alice')));
});


test('reservations reject email fields and protect legacy email records', async () => {
  await assertFails(setDoc(doc(alice(), 'usernames/leak'), { uid: 'alice', email: 'a@x.com' }));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'usernames/legacy'), { uid: 'alice', email: 'a@x.com' });
  });
  await assertFails(getDoc(doc(anon(), 'usernames/legacy')));
  await assertFails(getDoc(doc(bob(), 'usernames/legacy')));
  await assertSucceeds(getDoc(doc(alice(), 'usernames/legacy')));
  await assertSucceeds(setDoc(doc(alice(), 'usernames/legacy'), { uid: 'alice' }));
  await assertSucceeds(getDoc(doc(anon(), 'usernames/legacy')));
});
