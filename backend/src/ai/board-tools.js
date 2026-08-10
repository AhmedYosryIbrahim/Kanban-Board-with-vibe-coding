import {
  createCard,
  deleteCard,
  moveCard,
  renameColumn,
  updateCard,
} from '../db/board.js';
import { transaction } from '../db/index.js';

/**
 * Applies the AI's operations to the board, all or nothing.
 *
 * Everything runs through the same functions the HTTP API uses, so the AI
 * cannot reach data the user could not reach themselves, and ownership checks
 * are not duplicated. One bad operation aborts the whole batch: the outer
 * transaction rolls back, leaving the board exactly as it was.
 */
export function applyOperations(db, board, operations) {
  if (operations.length === 0) return false;

  transaction(db, () => {
    for (const operation of operations) {
      applyOne(db, board, operation);
    }
  });

  return true;
}

function applyOne(db, board, operation) {
  const { op, columnId, cardId, title, details, position } = operation;

  switch (op) {
    case 'create_card':
      createCard(db, board, columnId, title, details ?? '');
      return;

    case 'update_card':
      updateCard(db, board, cardId, {
        ...(title === null ? {} : { title }),
        ...(details === null ? {} : { details }),
      });
      return;

    case 'move_card':
      moveCard(db, board, cardId, columnId, position);
      return;

    case 'delete_card':
      deleteCard(db, board, cardId);
      return;

    case 'rename_column':
      renameColumn(db, board, columnId, title);
      return;

    default:
      throw new Error(`Unknown operation: ${op}`);
  }
}
