import { randomUUID } from 'node:crypto';

import { fail } from '../fail.js';
import { transaction } from './index.js';

/** The signed in user's board. Board ids never come from the client. */
export function getBoardForUser(db, username) {
  const board = db
    .prepare(
      `SELECT b.id, b.name, b.subtitle
       FROM boards b
       JOIN users u ON u.id = b.user_id
       WHERE u.username = ?
       ORDER BY b.id
       LIMIT 1`,
    )
    .get(username);

  if (!board) fail(404, 'No board for this user');

  return board;
}

/** The whole board as the frontend and the AI consume it. */
export function readBoard(db, board) {
  const columns = db
    .prepare(
      `SELECT id, title FROM board_columns
       WHERE board_id = ?
       ORDER BY position`,
    )
    .all(board.id);

  const cards = db
    .prepare(
      `SELECT c.id, c.column_id, c.title, c.details
       FROM cards c
       JOIN board_columns bc ON bc.id = c.column_id
       WHERE bc.board_id = ?
       ORDER BY bc.position, c.position`,
    )
    .all(board.id);

  const byColumn = new Map(columns.map((column) => [column.id, []]));
  for (const card of cards) {
    byColumn.get(card.column_id).push({
      id: card.id,
      title: card.title,
      details: card.details,
    });
  }

  return {
    id: board.id,
    name: board.name,
    subtitle: board.subtitle,
    columns: columns.map((column) => ({
      id: column.id,
      title: column.title,
      cards: byColumn.get(column.id),
    })),
  };
}

function requireColumn(db, board, columnId, status = 404) {
  const column = db
    .prepare('SELECT id, title FROM board_columns WHERE id = ? AND board_id = ?')
    .get(columnId, board.id);

  if (!column) fail(status, 'Column not found');

  return column;
}

/**
 * Looks the card up through its column, so a card on someone else's board is
 * indistinguishable from one that does not exist.
 */
function requireCard(db, board, cardId) {
  const card = db
    .prepare(
      `SELECT c.id, c.column_id, c.title, c.details, c.position
       FROM cards c
       JOIN board_columns bc ON bc.id = c.column_id
       WHERE c.id = ? AND bc.board_id = ?`,
    )
    .get(cardId, board.id);

  if (!card) fail(404, 'Card not found');

  return card;
}

export function renameColumn(db, board, columnId, title) {
  requireColumn(db, board, columnId);

  const trimmed = (title ?? '').trim();
  if (!trimmed) fail(400, 'Title is required');

  db.prepare('UPDATE board_columns SET title = ? WHERE id = ?').run(
    trimmed,
    columnId,
  );

  return { id: columnId, title: trimmed };
}

export function createCard(db, board, columnId, title, details) {
  requireColumn(db, board, columnId, 400);

  const trimmed = (title ?? '').trim();
  if (!trimmed) fail(400, 'Title is required');

  const id = randomUUID();

  transaction(db, () => {
    const { count } = db
      .prepare('SELECT COUNT(*) AS count FROM cards WHERE column_id = ?')
      .get(columnId);

    db.prepare(
      'INSERT INTO cards (id, column_id, title, details, position) VALUES (?, ?, ?, ?, ?)',
    ).run(id, columnId, trimmed, (details ?? '').trim(), count);
  });

  return { id, columnId, title: trimmed, details: (details ?? '').trim() };
}

export function updateCard(db, board, cardId, { title, details }) {
  const card = requireCard(db, board, cardId);

  const nextTitle = title === undefined ? card.title : title.trim();
  if (!nextTitle) fail(400, 'Title is required');

  const nextDetails = details === undefined ? card.details : details.trim();

  db.prepare('UPDATE cards SET title = ?, details = ? WHERE id = ?').run(
    nextTitle,
    nextDetails,
    cardId,
  );

  return { id: cardId, title: nextTitle, details: nextDetails };
}

export function deleteCard(db, board, cardId) {
  const card = requireCard(db, board, cardId);

  transaction(db, () => {
    db.prepare('DELETE FROM cards WHERE id = ?').run(cardId);
    closeGap(db, card.column_id, card.position);
  });
}

/**
 * Moves a card, where position is its index in the destination column once the
 * move is done. Out of range values are clamped rather than rejected, so a
 * drop past the end of a column lands at the end.
 */
export function moveCard(db, board, cardId, toColumnId, position) {
  const card = requireCard(db, board, cardId);
  requireColumn(db, board, toColumnId, 400);

  transaction(db, () => {
    closeGap(db, card.column_id, card.position);

    const { count } = db
      .prepare(
        'SELECT COUNT(*) AS count FROM cards WHERE column_id = ? AND id != ?',
      )
      .get(toColumnId, cardId);

    const target = Math.min(Math.max(position ?? count, 0), count);

    db.prepare(
      `UPDATE cards SET position = position + 1
       WHERE column_id = ? AND position >= ? AND id != ?`,
    ).run(toColumnId, target, cardId);

    db.prepare('UPDATE cards SET column_id = ?, position = ? WHERE id = ?').run(
      toColumnId,
      target,
      cardId,
    );
  });
}

/** Pulls every card after the vacated slot down one, keeping positions dense. */
function closeGap(db, columnId, position) {
  db.prepare(
    'UPDATE cards SET position = position - 1 WHERE column_id = ? AND position > ?',
  ).run(columnId, position);
}
