import { afterEach, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import { assertContiguous, cardsIn, startTestServer } from './support/server.js';

let app;
let columns;

beforeEach(async () => {
  app = await startTestServer();
  columns = (await app.board()).columns;
});

afterEach(() => {
  app.close();
});

const todo = () => columns[0];
const inProgress = () => columns[1];

test('GET /api/board returns the seeded columns in order with their cards', async () => {
  const board = await app.board();

  assert.equal(board.name, 'Product Roadmap');
  assert.equal(board.subtitle, 'Q4 delivery board');
  assert.deepEqual(
    board.columns.map((column) => column.title),
    ['To Do', 'In Progress', 'Review', 'Blocked', 'Done'],
  );
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline'],
  );
  assert.deepEqual(Object.keys(board.columns[0].cards[0]).sort(), [
    'details',
    'id',
    'title',
  ]);
});

test('every board route requires a session', async () => {
  const cardId = todo().cards[0].id;
  const calls = [
    ['/api/board', 'GET'],
    [`/api/columns/${todo().id}`, 'PATCH'],
    ['/api/cards', 'POST'],
    [`/api/cards/${cardId}`, 'PATCH'],
    [`/api/cards/${cardId}`, 'DELETE'],
    [`/api/cards/${cardId}/move`, 'POST'],
  ];

  for (const [path, method] of calls) {
    const response = await app.request(path, { method, signedIn: false });
    assert.equal(response.status, 401, `${method} ${path} should be 401`);
  }
});

test('renaming a column persists', async () => {
  const response = await app.request(`/api/columns/${todo().id}`, {
    method: 'PATCH',
    body: { title: 'Backlog' },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { id: todo().id, title: 'Backlog' });

  const board = await app.board();
  assert.equal(board.columns[0].title, 'Backlog');
  assert.equal(board.columns[1].title, 'In Progress');
});

test('renaming a column to an empty title returns 400', async () => {
  const response = await app.request(`/api/columns/${todo().id}`, {
    method: 'PATCH',
    body: { title: '   ' },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'Title is required' });
  assert.equal((await app.board()).columns[0].title, 'To Do');
});

test('renaming an unknown column returns 404', async () => {
  const response = await app.request('/api/columns/does-not-exist', {
    method: 'PATCH',
    body: { title: 'Backlog' },
  });

  assert.equal(response.status, 404);
});

test('creating a card puts it last in its column', async () => {
  const response = await app.request('/api/cards', {
    method: 'POST',
    body: { columnId: todo().id, title: 'Third task', details: 'Some details' },
  });

  assert.equal(response.status, 201);
  const created = await response.json();
  assert.equal(created.title, 'Third task');
  assert.ok(created.id);

  const board = await app.board();
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline', 'Third task'],
  );
  assertContiguous(app.db, todo().id);
});

test('creating a card without a title returns 400', async () => {
  const response = await app.request('/api/cards', {
    method: 'POST',
    body: { columnId: todo().id, title: '  ' },
  });

  assert.equal(response.status, 400);
  assert.equal((await app.board()).columns[0].cards.length, 2);
});

test('creating a card in an unknown column returns 400', async () => {
  const response = await app.request('/api/cards', {
    method: 'POST',
    body: { columnId: 'nope', title: 'Orphan' },
  });

  assert.equal(response.status, 400);
});

test('updating a card changes its title and details', async () => {
  const cardId = todo().cards[0].id;

  const response = await app.request(`/api/cards/${cardId}`, {
    method: 'PATCH',
    body: { title: 'Renamed', details: 'Fresh details' },
  });

  assert.equal(response.status, 200);

  const card = (await app.board()).columns[0].cards[0];
  assert.equal(card.title, 'Renamed');
  assert.equal(card.details, 'Fresh details');
});

test('updating only the details leaves the title alone', async () => {
  const cardId = todo().cards[0].id;

  await app.request(`/api/cards/${cardId}`, {
    method: 'PATCH',
    body: { details: 'Only this' },
  });

  const card = (await app.board()).columns[0].cards[0];
  assert.equal(card.title, 'Design onboarding flow');
  assert.equal(card.details, 'Only this');
});

test('updating an unknown card returns 404', async () => {
  const response = await app.request('/api/cards/nope', {
    method: 'PATCH',
    body: { title: 'Renamed' },
  });

  assert.equal(response.status, 404);
});

test('deleting a card removes it and keeps positions contiguous', async () => {
  const cardId = todo().cards[0].id;

  const response = await app.request(`/api/cards/${cardId}`, {
    method: 'DELETE',
  });

  assert.equal(response.status, 204);

  const board = await app.board();
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Set up CI pipeline'],
  );
  assertContiguous(app.db, todo().id);
});

test('deleting an unknown card returns 404', async () => {
  const response = await app.request('/api/cards/nope', { method: 'DELETE' });

  assert.equal(response.status, 404);
});

test('moving a card to another column at index 0 reorders both columns', async () => {
  const cardId = todo().cards[1].id;

  const response = await app.request(`/api/cards/${cardId}/move`, {
    method: 'POST',
    body: { toColumnId: inProgress().id, position: 0 },
  });

  assert.equal(response.status, 200);
  const board = await response.json();

  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Design onboarding flow'],
  );
  assert.deepEqual(
    board.columns[1].cards.map((card) => card.title),
    ['Set up CI pipeline', 'Implement drag and drop'],
  );
  assertContiguous(app.db, todo().id);
  assertContiguous(app.db, inProgress().id);
});

test('moving a card down within its own column handles the shift', async () => {
  await app.request('/api/cards', {
    method: 'POST',
    body: { columnId: todo().id, title: 'Third task' },
  });

  const first = (await app.board()).columns[0].cards[0];

  await app.request(`/api/cards/${first.id}/move`, {
    method: 'POST',
    body: { toColumnId: todo().id, position: 2 },
  });

  const board = await app.board();
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Set up CI pipeline', 'Third task', 'Design onboarding flow'],
  );
  assertContiguous(app.db, todo().id);
});

test('moving a card up within its own column handles the shift', async () => {
  const second = todo().cards[1].id;

  await app.request(`/api/cards/${second}/move`, {
    method: 'POST',
    body: { toColumnId: todo().id, position: 0 },
  });

  const board = await app.board();
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Set up CI pipeline', 'Design onboarding flow'],
  );
  assertContiguous(app.db, todo().id);
});

test('a position past the end of a column clamps to the end', async () => {
  const cardId = todo().cards[0].id;

  await app.request(`/api/cards/${cardId}/move`, {
    method: 'POST',
    body: { toColumnId: inProgress().id, position: 99 },
  });

  const board = await app.board();
  assert.deepEqual(
    board.columns[1].cards.map((card) => card.title),
    ['Implement drag and drop', 'Design onboarding flow'],
  );
  assertContiguous(app.db, inProgress().id);
});

test('a negative position clamps to the start', async () => {
  const cardId = todo().cards[0].id;

  await app.request(`/api/cards/${cardId}/move`, {
    method: 'POST',
    body: { toColumnId: inProgress().id, position: -5 },
  });

  const board = await app.board();
  assert.deepEqual(
    board.columns[1].cards.map((card) => card.title),
    ['Design onboarding flow', 'Implement drag and drop'],
  );
});

test('moving to a column that does not exist returns 400 and changes nothing', async () => {
  const cardId = todo().cards[0].id;

  const response = await app.request(`/api/cards/${cardId}/move`, {
    method: 'POST',
    body: { toColumnId: 'nope', position: 0 },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(
    cardsIn(app.db, todo().id).map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline'],
  );
});

test('moving an unknown card returns 404', async () => {
  const response = await app.request('/api/cards/nope/move', {
    method: 'POST',
    body: { toColumnId: inProgress().id, position: 0 },
  });

  assert.equal(response.status, 404);
});

test('a card on another board is not reachable', async () => {
  app.db
    .prepare('INSERT INTO users (id, username) VALUES (?, ?)')
    .run(2, 'someone-else');
  app.db
    .prepare('INSERT INTO boards (id, user_id, name) VALUES (?, ?, ?)')
    .run(2, 2, 'Their board');
  app.db
    .prepare(
      'INSERT INTO board_columns (id, board_id, title, position) VALUES (?, ?, ?, ?)',
    )
    .run('their-column', 2, 'Their To Do', 0);
  app.db
    .prepare(
      'INSERT INTO cards (id, column_id, title, position) VALUES (?, ?, ?, ?)',
    )
    .run('their-card', 'their-column', 'Their card', 0);

  assert.equal(
    (
      await app.request('/api/cards/their-card', {
        method: 'PATCH',
        body: { title: 'Hijacked' },
      })
    ).status,
    404,
  );
  assert.equal(
    (await app.request('/api/cards/their-card', { method: 'DELETE' })).status,
    404,
  );
  assert.equal(
    (
      await app.request('/api/columns/their-column', {
        method: 'PATCH',
        body: { title: 'Hijacked' },
      })
    ).status,
    404,
  );
  assert.equal(
    (
      await app.request('/api/cards', {
        method: 'POST',
        body: { columnId: 'their-column', title: 'Injected' },
      })
    ).status,
    400,
  );

  assert.equal(
    app.db.prepare('SELECT title FROM cards WHERE id = ?').get('their-card')
      .title,
    'Their card',
  );
});
