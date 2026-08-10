/** The board's conversation, oldest first. The integer id is the order. */
export function readMessages(db, boardId) {
  return db
    .prepare(
      'SELECT role, content FROM messages WHERE board_id = ? ORDER BY id',
    )
    .all(boardId);
}

export function addMessage(db, boardId, role, content) {
  db.prepare(
    'INSERT INTO messages (board_id, role, content) VALUES (?, ?, ?)',
  ).run(boardId, role, content);
}
