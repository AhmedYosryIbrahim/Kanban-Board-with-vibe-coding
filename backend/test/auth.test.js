import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

import { createApp } from '../src/app.js';

const staticDir = fileURLToPath(new URL('./fixtures/web', import.meta.url));

let server;
let baseUrl;

before(async () => {
  server = createApp({ staticDir, sessionSecret: 'test-secret' }).listen(0);
  await once(server, 'listening');
  baseUrl = `http://localhost:${server.address().port}`;
});

after(() => {
  server.close();
});

function login({ username = 'user', password = 'password' } = {}) {
  return fetch(`${baseUrl}/api/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
}

/** Turns a response's Set-Cookie headers into a Cookie request header. */
function cookieHeader(response) {
  return response.headers
    .getSetCookie()
    .map((cookie) => cookie.split(';')[0])
    .join('; ');
}

function me(cookie) {
  return fetch(`${baseUrl}/api/me`, {
    headers: cookie ? { cookie } : {},
  });
}

test('login with correct credentials returns the user and sets a cookie', async () => {
  const response = await login();

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { username: 'user' });

  const [cookie] = response.headers.getSetCookie();
  assert.match(cookie, /^kanban_session=/);
  assert.match(cookie, /HttpOnly/i);
  assert.match(cookie, /SameSite=Lax/i);
});

test('login with wrong credentials returns 401 and sets no cookie', async () => {
  const response = await login({ password: 'wrong' });

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: 'Invalid username or password',
  });
  assert.deepEqual(response.headers.getSetCookie(), []);
});

test('login with an unknown username returns 401', async () => {
  const response = await login({ username: 'someone-else' });

  assert.equal(response.status, 401);
  assert.deepEqual(response.headers.getSetCookie(), []);
});

test('login with no body returns 401 rather than crashing', async () => {
  const response = await fetch(`${baseUrl}/api/login`, { method: 'POST' });

  assert.equal(response.status, 401);
});

test('GET /api/me without a cookie returns 401', async () => {
  const response = await me();

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'Not signed in' });
});

test('GET /api/me with the login cookie returns the username', async () => {
  const cookie = cookieHeader(await login());

  const response = await me(cookie);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { username: 'user' });
});

test('a cookie with a tampered signature is rejected', async () => {
  const cookie = cookieHeader(await login());
  const tampered = cookie.slice(0, -1) + (cookie.endsWith('A') ? 'B' : 'A');

  const response = await me(tampered);

  assert.equal(response.status, 401);
});

test('a cookie with a tampered username is rejected', async () => {
  const cookie = cookieHeader(await login());
  const forged = cookie.replace('s%3Auser.', 's%3Aadmin.');

  const response = await me(forged);

  assert.equal(response.status, 401);
});

test('an unsigned cookie is rejected', async () => {
  const response = await me('kanban_session=user');

  assert.equal(response.status, 401);
});

test('a cookie signed with a different secret is rejected', async () => {
  const otherServer = createApp({
    staticDir,
    sessionSecret: 'a-different-secret',
  }).listen(0);
  await once(otherServer, 'listening');
  const otherUrl = `http://localhost:${otherServer.address().port}`;

  const foreign = await fetch(`${otherUrl}/api/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ username: 'user', password: 'password' }),
  });
  const response = await me(cookieHeader(foreign));

  assert.equal(response.status, 401);
  otherServer.close();
});

test('logout clears the cookie and ends the session', async () => {
  const cookie = cookieHeader(await login());
  assert.equal((await me(cookie)).status, 200);

  const logout = await fetch(`${baseUrl}/api/logout`, {
    method: 'POST',
    headers: { cookie },
  });

  assert.equal(logout.status, 204);

  const cleared = logout.headers.getSetCookie().join(';');
  assert.match(cleared, /^kanban_session=;/);

  // The browser drops the cookie, so a later request arrives without one.
  assert.equal((await me()).status, 401);
});

test('health stays reachable without a session', async () => {
  const response = await fetch(`${baseUrl}/api/health`);

  assert.equal(response.status, 200);
});
