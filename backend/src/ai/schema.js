export const OPERATIONS = [
  'create_card',
  'update_card',
  'move_card',
  'delete_card',
  'rename_column',
];

// Strict Structured Outputs requires every property to be listed in `required`
// and forbids extra ones, so fields that only apply to some operations are
// declared nullable and the model sends null when they do not apply.
export const boardResponseFormat = {
  type: 'json_schema',
  json_schema: {
    name: 'board_response',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['reply', 'operations'],
      properties: {
        reply: {
          type: 'string',
          description: 'What to say to the user, in plain prose.',
        },
        operations: {
          type: 'array',
          description: 'Board changes to apply. Empty when only answering.',
          items: {
            type: 'object',
            additionalProperties: false,
            required: [
              'op',
              'columnId',
              'cardId',
              'title',
              'details',
              'position',
            ],
            properties: {
              op: { type: 'string', enum: OPERATIONS },
              columnId: {
                type: ['string', 'null'],
                description:
                  'Target column. The destination column for move_card.',
              },
              cardId: { type: ['string', 'null'] },
              title: { type: ['string', 'null'] },
              details: { type: ['string', 'null'] },
              position: {
                type: ['integer', 'null'],
                description: 'Index within the destination column, from 0.',
              },
            },
          },
        },
      },
    },
  },
};

/** Fields that must be present, per operation. */
const REQUIRED = {
  create_card: ['columnId', 'title'],
  update_card: ['cardId'],
  move_card: ['cardId', 'columnId'],
  delete_card: ['cardId'],
  rename_column: ['columnId', 'title'],
};

const blank = (value) => value === null || value === undefined || value === '';

/**
 * Parses the model's response and checks it is shaped well enough to apply.
 * Structured Outputs makes this unlikely to fail, but the response is still
 * remote input and nothing downstream should assume it is well formed.
 */
export function parseBoardResponse(content) {
  let parsed;

  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error('The AI response was not valid JSON');
  }

  if (typeof parsed?.reply !== 'string') {
    throw new Error('The AI response had no reply');
  }

  const operations = parsed.operations ?? [];
  if (!Array.isArray(operations)) {
    throw new Error('The AI response had a malformed operations list');
  }

  return {
    reply: parsed.reply,
    operations: operations.map(normalizeOperation),
  };
}

function normalizeOperation(operation) {
  if (!operation || typeof operation !== 'object') {
    throw new Error('The AI returned a malformed operation');
  }

  const { op } = operation;
  if (!OPERATIONS.includes(op)) {
    throw new Error(`The AI returned an unknown operation: ${op}`);
  }

  for (const field of REQUIRED[op]) {
    if (blank(operation[field])) {
      throw new Error(`The AI omitted ${field} on ${op}`);
    }
  }

  if (op === 'update_card' && blank(operation.title) && blank(operation.details)) {
    throw new Error('The AI omitted both title and details on update_card');
  }

  return {
    op,
    columnId: operation.columnId ?? null,
    cardId: operation.cardId ?? null,
    title: operation.title ?? null,
    details: operation.details ?? null,
    position: operation.position ?? null,
  };
}
