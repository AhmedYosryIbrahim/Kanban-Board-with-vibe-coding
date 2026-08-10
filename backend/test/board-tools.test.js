import { beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import { applyOperations } from '../src/ai/board-tools.js';
import { getBoardForUser, readBoard } from '../src/db/board.js';
import { openDatabase } from '../src/db/index.js';

let db;
let board;

beforeEach(() => {
  db = openDatabase(':memory:');
  board = getBoardForUser(db, 'user');
});

const columns = () => readBoard(db, board).columns;
const column = (title) => columns().find((c) => c.title === title);
const titles = (title) => column(title).cards.map((card) => card.title);

const operation = (overrides) => ({
  op: 'create_card',
  columnId: null,
  cardId: null,
  title: null,
  details: null,
  position: null,
  ...overrides,
});

test('create_card adds a card at the end of its column', () => {
  const changed = applyOperations(db, board, [
    operation({
      op: 'create_card',
      columnId: column('To Do').id,
      title: 'From the AI',
      details: 'Because I asked',
    }),
  ]);

  assert.equal(changed, true);
  assert.deepEqual(titles('To Do'), [
    'Design onboarding flow',
    'Set up CI pipeline',
    'From the AI',
  ]);
  assert.equal(column('To Do').cards.at(-1).details, 'Because I asked');
});

test('update_card changes the fields it is given', () => {
  const card = column('To Do').cards[0];

  applyOperations(db, board, [
    operation({ op: 'update_card', cardId: card.id, title: 'Renamed' }),
  ]);

  assert.equal(column('To Do').cards[0].title, 'Renamed');
  assert.equal(
    column('To Do').cards[0].details,
    'Sketch wireframes for the new user onboarding.',
  );
});

test('move_card moves a card to another column at a position', () => {
  const card = column('To Do').cards[0];

  applyOperations(db, board, [
    operation({
      op: 'move_card',
      cardId: card.id,
      columnId: column('In Progress').id,
      position: 0,
    }),
  ]);

  assert.deepEqual(titles('In Progress'), [
    'Design onboarding flow',
    'Implement drag and drop',
  ]);
  assert.deepEqual(titles('To Do'), ['Set up CI pipeline']);
});

test('delete_card removes a card', () => {
  const card = column('To Do').cards[0];

  applyOperations(db, board, [
    operation({ op: 'delete_card', cardId: card.id }),
  ]);

  assert.deepEqual(titles('To Do'), ['Set up CI pipeline']);
});

test('rename_column renames a column', () => {
  applyOperations(db, board, [
    operation({
      op: 'rename_column',
      columnId: column('To Do').id,
      title: 'Backlog',
    }),
  ]);

  assert.equal(columns()[0].title, 'Backlog');
});

test('an empty batch changes nothing and reports no change', () => {
  const before = JSON.stringify(readBoard(db, board));

  assert.equal(applyOperations(db, board, []), false);
  assert.equal(JSON.stringify(readBoard(db, board)), before);
});

test('several operations in one batch all apply', () => {
  const todo = column('To Do');

  applyOperations(db, board, [
    operation({ op: 'create_card', columnId: todo.id, title: 'First' }),
    operation({ op: 'create_card', columnId: todo.id, title: 'Second' }),
    operation({
      op: 'rename_column',
      columnId: todo.id,
      title: 'Backlog',
    }),
    operation({ op: 'delete_card', cardId: todo.cards[0].id }),
  ]);

  assert.equal(columns()[0].title, 'Backlog');
  assert.deepEqual(titles('Backlog'), ['Set up CI pipeline', 'First', 'Second']);
});

test('one bad operation rolls the whole batch back', () => {
  const todo = column('To Do');
  const before = JSON.stringify(readBoard(db, board));

  assert.throws(() =>
    applyOperations(db, board, [
      operation({ op: 'create_card', columnId: todo.id, title: 'Ghost' }),
      operation({
        op: 'rename_column',
        columnId: todo.id,
        title: 'Backlog',
      }),
      operation({ op: 'delete_card', cardId: 'no-such-card' }),
    ]),
  );

  // Not a single one of the three should have survived.
  assert.equal(JSON.stringify(readBoard(db, board)), before);
});

test('an unknown card id is rejected without a partial write', () => {
  const before = JSON.stringify(readBoard(db, board));

  assert.throws(
    () =>
      applyOperations(db, board, [
        operation({ op: 'update_card', cardId: 'nope', title: 'Hijacked' }),
      ]),
    /Card not found/,
  );

  assert.equal(JSON.stringify(readBoard(db, board)), before);
});

test('an unknown column id is rejected', () => {
  assert.throws(
    () =>
      applyOperations(db, board, [
        operation({ op: 'create_card', columnId: 'nope', title: 'Orphan' }),
      ]),
    /Column not found/,
  );
});

test('the AI cannot touch another user\'s board', () => {
  db.prepare('INSERT INTO users (id, username) VALUES (?, ?)').run(2, 'other');
  db.prepare('INSERT INTO boards (id, user_id, name) VALUES (?, ?, ?)').run(
    2,
    2,
    'Their board',
  );
  db.prepare(
    'INSERT INTO board_columns (id, board_id, title, position) VALUES (?, ?, ?, ?)',
  ).run('their-column', 2, 'Theirs', 0);
  db.prepare(
    'INSERT INTO cards (id, column_id, title, position) VALUES (?, ?, ?, ?)',
  ).run('their-card', 'their-column', 'Their card', 0);

  assert.throws(() =>
    applyOperations(db, board, [
      operation({ op: 'delete_card', cardId: 'their-card' }),
    ]),
  );

  assert.equal(
    db.prepare('SELECT title FROM cards WHERE id = ?').get('their-card').title,
    'Their card',
  );
});

test('a batch that moves and reorders keeps positions contiguous', () => {
  const todo = column('To Do');
  const done = column('Done');

  applyOperations(db, board, [
    operation({
      op: 'move_card',
      cardId: todo.cards[0].id,
      columnId: done.id,
      position: 0,
    }),
    operation({
      op: 'move_card',
      cardId: todo.cards[1].id,
      columnId: done.id,
      position: 0,
    }),
  ]);

  assert.deepEqual(titles('Done'), [
    'Set up CI pipeline',
    'Design onboarding flow',
    'Project kickoff meeting',
  ]);
  assert.deepEqual(titles('To Do'), []);

  const positions = db
    .prepare('SELECT position FROM cards WHERE column_id = ? ORDER BY position')
    .all(done.id)
    .map((row) => row.position);
  assert.deepEqual(positions, [0, 1, 2]);
});
