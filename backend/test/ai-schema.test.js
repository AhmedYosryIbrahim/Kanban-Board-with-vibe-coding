import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  boardResponseFormat,
  OPERATIONS,
  parseBoardResponse,
} from '../src/ai/schema.js';

const operation = (overrides) => ({
  op: 'create_card',
  columnId: 'col-1',
  cardId: null,
  title: 'A card',
  details: null,
  position: null,
  ...overrides,
});

test('the response format is strict and covers every operation', () => {
  const { json_schema: schema } = boardResponseFormat;

  assert.equal(schema.strict, true);
  assert.equal(schema.schema.additionalProperties, false);
  assert.deepEqual(schema.schema.required, ['reply', 'operations']);

  const item = schema.schema.properties.operations.items;
  assert.equal(item.additionalProperties, false);
  assert.deepEqual(item.properties.op.enum, OPERATIONS);

  // Strict mode requires every property to be listed as required.
  assert.deepEqual(
    [...item.required].sort(),
    Object.keys(item.properties).sort(),
  );
});

test('a valid response parses', () => {
  const { reply, operations } = parseBoardResponse(
    JSON.stringify({
      reply: 'Added it.',
      operations: [operation({})],
    }),
  );

  assert.equal(reply, 'Added it.');
  assert.equal(operations.length, 1);
  assert.equal(operations[0].op, 'create_card');
  assert.equal(operations[0].title, 'A card');
});

test('a chat-only response parses with no operations', () => {
  const { reply, operations } = parseBoardResponse(
    JSON.stringify({ reply: 'You have 6 cards.', operations: [] }),
  );

  assert.equal(reply, 'You have 6 cards.');
  assert.deepEqual(operations, []);
});

test('a missing operations list is treated as empty', () => {
  const { operations } = parseBoardResponse(JSON.stringify({ reply: 'Hi' }));

  assert.deepEqual(operations, []);
});

test('non-JSON is rejected', () => {
  assert.throws(
    () => parseBoardResponse('I am afraid I cannot do that'),
    /not valid JSON/,
  );
});

test('a response without a reply is rejected', () => {
  assert.throws(
    () => parseBoardResponse(JSON.stringify({ operations: [] })),
    /no reply/,
  );
});

test('a non-array operations list is rejected', () => {
  assert.throws(
    () => parseBoardResponse(JSON.stringify({ reply: 'x', operations: {} })),
    /malformed operations list/,
  );
});

test('an unknown operation name is rejected', () => {
  assert.throws(
    () =>
      parseBoardResponse(
        JSON.stringify({
          reply: 'x',
          operations: [operation({ op: 'drop_database' })],
        }),
      ),
    /unknown operation: drop_database/,
  );
});

test('each operation must carry the fields it needs', () => {
  const missing = [
    ['create_card', { columnId: null }, /omitted columnId on create_card/],
    ['create_card', { title: null }, /omitted title on create_card/],
    [
      'delete_card',
      { op: 'delete_card', cardId: null },
      /omitted cardId on delete_card/,
    ],
    [
      'move_card',
      { op: 'move_card', cardId: 'c1', columnId: null },
      /omitted columnId on move_card/,
    ],
    [
      'rename_column',
      { op: 'rename_column', columnId: 'col-1', title: null },
      /omitted title on rename_column/,
    ],
  ];

  for (const [, overrides, expected] of missing) {
    assert.throws(
      () =>
        parseBoardResponse(
          JSON.stringify({ reply: 'x', operations: [operation(overrides)] }),
        ),
      expected,
    );
  }
});

test('update_card must change at least one field', () => {
  assert.throws(
    () =>
      parseBoardResponse(
        JSON.stringify({
          reply: 'x',
          operations: [
            operation({
              op: 'update_card',
              cardId: 'c1',
              title: null,
              details: null,
            }),
          ],
        }),
      ),
    /omitted both title and details/,
  );
});

test('update_card with only details is accepted', () => {
  const { operations } = parseBoardResponse(
    JSON.stringify({
      reply: 'x',
      operations: [
        operation({
          op: 'update_card',
          cardId: 'c1',
          title: null,
          details: 'Just this',
        }),
      ],
    }),
  );

  assert.equal(operations[0].details, 'Just this');
  assert.equal(operations[0].title, null);
});

test('a malformed operation entry is rejected', () => {
  assert.throws(
    () =>
      parseBoardResponse(
        JSON.stringify({ reply: 'x', operations: ['delete everything'] }),
      ),
    /malformed operation/,
  );
});
