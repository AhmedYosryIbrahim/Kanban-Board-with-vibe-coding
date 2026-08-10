import assert from 'node:assert/strict';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

import { createApp } from '../../src/app.js';
import { openDatabase } from '../../src/db/index.js';

const staticDir = fileURLToPath(new URL('../fixtures/web', import.meta.url));

/** An in-memory database behind a listening app, already signed in. */
export async function startTestServer() {
  const db = openDatabase(':memory:');
  const server = createApp({
    db,
    staticDir,
    sessionSecret: 'test-secret',
  }).listen(0);
  await once(server, 'listening');

  const baseUrl = `http://localhost:${server.address().port}`;

  const login = await fetch(`${baseUrl}/api/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ username: 'user', password: 'password' }),
  });
  const cookie = login.headers
    .getSetCookie()
    .map((value) => value.split(';')[0])
    .join('; ');

  const request = (path, { method = 'GET', body, signedIn = true } = {}) =>
    fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        ...(signedIn ? { cookie } : {}),
        ...(body ? { 'content-type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });

  const board = () => request('/api/board').then((r) => r.json());

  return { db, baseUrl, cookie, request, board, close: () => server.close() };
}

/** Card titles in a column, ordered by position. */
export function cardsIn(db, columnId) {
  return db
    .prepare(
      'SELECT title, position FROM cards WHERE column_id = ? ORDER BY position',
    )
    .all(columnId);
}

/** Positions must stay dense and zero based after any sequence of moves. */
export function assertContiguous(db, columnId) {
  const rows = cardsIn(db, columnId);

  assert.deepEqual(
    rows.map((row) => row.position),
    rows.map((_, index) => index),
    `positions in column ${columnId} are not contiguous from 0`,
  );
}
