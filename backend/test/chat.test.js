import { afterEach, test } from 'node:test';
import assert from 'node:assert/strict';

import { HISTORY_LIMIT } from '../src/ai/prompt.js';
import { startTestServer } from './support/server.js';

let app;

afterEach(() => {
  app?.close();
  app = undefined;
});

/** Stubs the model with a canned reply, recording what it was sent. */
function stubAi(response) {
  const calls = [];

  const callAi = async (messages, options) => {
    calls.push({ messages, options });
    const next = typeof response === 'function' ? response(calls.length) : response;
    return JSON.stringify(next);
  };

  return { callAi, calls };
}

const operation = (overrides) => ({
  op: 'create_card',
  columnId: null,
  cardId: null,
  title: null,
  details: null,
  position: null,
  ...overrides,
});

const chat = (message) =>
  app.request('/api/chat', { method: 'POST', body: { message } });

test('a chat-only answer changes nothing and reports no change', async () => {
  const { callAi, calls } = stubAi({ reply: 'You have 6 cards.', operations: [] });
  app = await startTestServer({ callAi });
  const before = JSON.stringify(await app.board());

  const response = await chat('How many cards do I have?');

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    reply: 'You have 6 cards.',
    boardChanged: false,
  });
  assert.equal(calls.length, 1);
  assert.equal(JSON.stringify(await app.board()), before);
});

test('the model is sent the board JSON, the schema, and the user message', async () => {
  const { callAi, calls } = stubAi({ reply: 'ok', operations: [] });
  app = await startTestServer({ callAi });

  await chat('What is on my board?');

  const { messages, options } = calls[0];
  const [system] = messages;

  assert.equal(system.role, 'system');
  assert.match(system.content, /Product Roadmap/);
  assert.match(system.content, /Design onboarding flow/);
  assert.match(system.content, /Never guess an id/);
  assert.match(system.content, /The server assigns the new card's id/);

  assert.deepEqual(messages.at(-1), {
    role: 'user',
    content: 'What is on my board?',
  });

  assert.equal(options.responseFormat.json_schema.strict, true);
  assert.equal(options.responseFormat.json_schema.name, 'board_response');
});

test('creating a card through chat updates the board', async () => {
  let columnId;
  const { callAi } = stubAi(() => ({
    reply: 'Added it.',
    operations: [
      operation({ op: 'create_card', columnId, title: 'From chat' }),
    ],
  }));
  app = await startTestServer({ callAi });
  columnId = (await app.board()).columns[0].id;

  const response = await chat('Add a card called From chat');
  assert.deepEqual(await response.json(), {
    reply: 'Added it.',
    boardChanged: true,
  });

  const board = await app.board();
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline', 'From chat'],
  );
});

test('several operations from one reply all apply', async () => {
  let columnId;
  const { callAi } = stubAi(() => ({
    reply: 'Done.',
    operations: [
      operation({ op: 'create_card', columnId, title: 'One' }),
      operation({ op: 'create_card', columnId, title: 'Two' }),
      operation({ op: 'rename_column', columnId, title: 'Backlog' }),
    ],
  }));
  app = await startTestServer({ callAi });
  columnId = (await app.board()).columns[0].id;

  await chat('Add two cards and rename the column');

  const board = await app.board();
  assert.equal(board.columns[0].title, 'Backlog');
  assert.deepEqual(
    board.columns[0].cards.map((card) => card.title),
    ['Design onboarding flow', 'Set up CI pipeline', 'One', 'Two'],
  );
});

test('an unknown id rolls the batch back and the reply says so', async () => {
  let columnId;
  const { callAi } = stubAi(() => ({
    reply: 'Done, I moved it.',
    operations: [
      operation({ op: 'create_card', columnId, title: 'Ghost' }),
      operation({ op: 'delete_card', cardId: 'no-such-card' }),
    ],
  }));
  app = await startTestServer({ callAi });
  columnId = (await app.board()).columns[0].id;
  const before = JSON.stringify(await app.board());

  const response = await chat('Delete the card about widgets');
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.boardChanged, false);
  assert.match(body.reply, /^I was not able to update the board: /);
  assert.match(body.reply, /Card not found/);

  // Neither operation survived, including the valid one.
  assert.equal(JSON.stringify(await app.board()), before);
});

test('a malformed model response surfaces as an error', async () => {
  const callAi = async () => 'I am afraid I cannot do that';
  app = await startTestServer({ callAi });

  const response = await chat('Add a card');

  assert.equal(response.status, 500);
  assert.match((await response.json()).error, /not valid JSON/);
});

test('the conversation is persisted and replayed to the model', async () => {
  const { callAi, calls } = stubAi({ reply: 'Noted.', operations: [] });
  app = await startTestServer({ callAi });

  await chat('First question');
  await chat('Second question');

  const second = calls[1].messages;
  assert.deepEqual(
    second.slice(1).map((m) => [m.role, m.content]),
    [
      ['user', 'First question'],
      ['assistant', 'Noted.'],
      ['user', 'Second question'],
    ],
  );

  const stored = await (await app.request('/api/chat')).json();
  assert.deepEqual(
    stored.messages.map((m) => [m.role, m.content]),
    [
      ['user', 'First question'],
      ['assistant', 'Noted.'],
      ['user', 'Second question'],
      ['assistant', 'Noted.'],
    ],
  );
});

test('replayed history is capped so it cannot grow without bound', async () => {
  const { callAi, calls } = stubAi({ reply: 'ok', operations: [] });
  app = await startTestServer({ callAi });

  for (let i = 0; i < HISTORY_LIMIT; i += 1) {
    await chat(`message ${i}`);
  }

  const last = calls.at(-1).messages;
  // system prompt + capped history + the new message
  assert.equal(last.length, HISTORY_LIMIT + 2);
});

test('an empty message is rejected without calling the model', async () => {
  const { callAi, calls } = stubAi({ reply: 'ok', operations: [] });
  app = await startTestServer({ callAi });

  const response = await chat('   ');

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'Message is required' });
  assert.equal(calls.length, 0);
});

test('chat requires a session', async () => {
  const { callAi, calls } = stubAi({ reply: 'ok', operations: [] });
  app = await startTestServer({ callAi });

  const post = await app.request('/api/chat', {
    method: 'POST',
    body: { message: 'Hello' },
    signedIn: false,
  });
  const get = await app.request('/api/chat', { signedIn: false });

  assert.equal(post.status, 401);
  assert.equal(get.status, 401);
  assert.equal(calls.length, 0);
});
