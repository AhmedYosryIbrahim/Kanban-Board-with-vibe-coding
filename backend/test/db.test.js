import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { openDatabase } from '../src/db/index.js';

function tempDbPath() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kanban-db-'));
  return { dir, file: path.join(dir, 'nested', 'kanban.db') };
}

test('openDatabase creates the file and its directory when missing', () => {
  const { dir, file } = tempDbPath();

  assert.equal(fs.existsSync(file), false);
  const db = openDatabase(file);
  assert.equal(fs.existsSync(file), true);

  db.close();
  fs.rmSync(dir, { recursive: true, force: true });
});

test('reopening an existing database does not seed a second time', () => {
  const { dir, file } = tempDbPath();

  const first = openDatabase(file);
  const seeded = first
    .prepare('SELECT COUNT(*) AS count FROM cards')
    .get().count;
  first.close();

  const second = openDatabase(file);
  const counts = {
    users: second.prepare('SELECT COUNT(*) AS count FROM users').get().count,
    boards: second.prepare('SELECT COUNT(*) AS count FROM boards').get().count,
    columns: second
      .prepare('SELECT COUNT(*) AS count FROM board_columns')
      .get().count,
    cards: second.prepare('SELECT COUNT(*) AS count FROM cards').get().count,
  };
  second.close();

  assert.deepEqual(counts, {
    users: 1,
    boards: 1,
    columns: 5,
    cards: seeded,
  });

  fs.rmSync(dir, { recursive: true, force: true });
});

test('the seed creates one user, one board, and 5 ordered columns', () => {
  const db = openDatabase(':memory:');

  const columns = db
    .prepare('SELECT title, position FROM board_columns ORDER BY position')
    .all();

  assert.deepEqual(
    columns.map((column) => column.title),
    ['To Do', 'In Progress', 'Review', 'Blocked', 'Done'],
  );
  assert.deepEqual(
    columns.map((column) => column.position),
    [0, 1, 2, 3, 4],
  );

  const { count } = db.prepare('SELECT COUNT(*) AS count FROM cards').get();
  assert.equal(count, 6);

  db.close();
});

test('seeded ids are unique opaque strings, not the frontend column names', () => {
  const db = openDatabase(':memory:');

  const ids = db.prepare('SELECT id FROM board_columns').all().map((r) => r.id);

  assert.equal(new Set(ids).size, 5);
  assert.equal(ids.includes('todo'), false);

  db.close();
});

test('deleting a board cascades to its columns and cards', () => {
  const db = openDatabase(':memory:');

  db.prepare('DELETE FROM boards WHERE id = 1').run();

  assert.equal(
    db.prepare('SELECT COUNT(*) AS count FROM board_columns').get().count,
    0,
  );
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM cards').get().count, 0);

  db.close();
});

test('foreign keys are enforced, so a card needs a real column', () => {
  const db = openDatabase(':memory:');

  assert.throws(() =>
    db
      .prepare(
        'INSERT INTO cards (id, column_id, title, position) VALUES (?, ?, ?, ?)',
      )
      .run('x', 'no-such-column', 'Orphan', 0),
  );

  db.close();
});

test('the role check constraint rejects unknown message roles', () => {
  const db = openDatabase(':memory:');

  assert.throws(() =>
    db
      .prepare('INSERT INTO messages (board_id, role, content) VALUES (?, ?, ?)')
      .run(1, 'system', 'nope'),
  );

  db.close();
});
