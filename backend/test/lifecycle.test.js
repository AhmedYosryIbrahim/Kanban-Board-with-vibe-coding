import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';

import { assertContiguous, startTestServer } from './support/server.js';

// One ordered scenario, sharing a server, so each step reads back what the
// previous one wrote. This is the path the Flutter app drives in Part 7.
let app;

before(async () => {
  app = await startTestServer();
});

after(() => {
  app.close();
});

const columnNamed = (board, title) =>
  board.columns.find((column) => column.title === title);

let createdCardId;

test('the board starts as the seed left it', async () => {
  const board = await app.board();

  assert.equal(board.name, 'Product Roadmap');
  assert.deepEqual(
    columnNamed(board, 'To Do').cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline'],
  );
});

test('a new card is readable straight back', async () => {
  const todo = columnNamed(await app.board(), 'To Do');

  const response = await app.request('/api/cards', {
    method: 'POST',
    body: {
      columnId: todo.id,
      title: 'Ship the API',
      details: 'Wire the frontend up',
    },
  });
  assert.equal(response.status, 201);
  createdCardId = (await response.json()).id;

  const board = await app.board();
  const card = columnNamed(board, 'To Do').cards.at(-1);
  assert.equal(card.id, createdCardId);
  assert.equal(card.title, 'Ship the API');
  assert.equal(card.details, 'Wire the frontend up');
});

test('the card moves to another column and both columns read back correctly', async () => {
  const board = await app.board();
  const inProgress = columnNamed(board, 'In Progress');

  const response = await app.request(`/api/cards/${createdCardId}/move`, {
    method: 'POST',
    body: { toColumnId: inProgress.id, position: 0 },
  });
  assert.equal(response.status, 200);

  const after = await app.board();
  assert.deepEqual(
    columnNamed(after, 'In Progress').cards.map((card) => card.title),
    ['Ship the API', 'Implement drag and drop'],
  );
  assert.deepEqual(
    columnNamed(after, 'To Do').cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline'],
  );
  assertContiguous(app.db, columnNamed(after, 'In Progress').id);
  assertContiguous(app.db, columnNamed(after, 'To Do').id);
});

test('editing the card persists', async () => {
  const response = await app.request(`/api/cards/${createdCardId}`, {
    method: 'PATCH',
    body: { title: 'Ship the API v2', details: 'Now with tests' },
  });
  assert.equal(response.status, 200);

  const card = columnNamed(await app.board(), 'In Progress').cards[0];
  assert.equal(card.title, 'Ship the API v2');
  assert.equal(card.details, 'Now with tests');
});

test('renaming a column persists', async () => {
  const todo = columnNamed(await app.board(), 'To Do');

  const response = await app.request(`/api/columns/${todo.id}`, {
    method: 'PATCH',
    body: { title: 'Backlog' },
  });
  assert.equal(response.status, 200);

  const board = await app.board();
  assert.equal(board.columns[0].title, 'Backlog');
  assert.equal(columnNamed(board, 'To Do'), undefined);
});

test('deleting the card leaves the column consistent', async () => {
  const response = await app.request(`/api/cards/${createdCardId}`, {
    method: 'DELETE',
  });
  assert.equal(response.status, 204);

  const board = await app.board();
  const inProgress = columnNamed(board, 'In Progress');
  assert.deepEqual(
    inProgress.cards.map((card) => card.title),
    ['Implement drag and drop'],
  );
  assertContiguous(app.db, inProgress.id);
});

test('the board still has its 5 columns after the whole cycle', async () => {
  const board = await app.board();

  assert.deepEqual(
    board.columns.map((column) => column.title),
    ['Backlog', 'In Progress', 'Review', 'Blocked', 'Done'],
  );
});
