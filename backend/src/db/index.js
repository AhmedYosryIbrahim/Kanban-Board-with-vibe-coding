import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

const schemaPath = fileURLToPath(new URL('./schema.sql', import.meta.url));

const SEED_BOARD = {
  name: 'Product Roadmap',
  subtitle: 'Q4 delivery board',
  columns: [
    {
      title: 'To Do',
      cards: [
        {
          title: 'Design onboarding flow',
          details: 'Sketch wireframes for the new user onboarding.',
        },
        {
          title: 'Set up CI pipeline',
          details: 'Configure automated build and test checks.',
        },
      ],
    },
    {
      title: 'In Progress',
      cards: [
        {
          title: 'Implement drag and drop',
          details: 'Allow cards to move between columns.',
        },
      ],
    },
    {
      title: 'Review',
      cards: [
        {
          title: 'Code review: auth module',
          details: 'Check for security issues before merging.',
        },
      ],
    },
    {
      title: 'Blocked',
      cards: [
        {
          title: 'Waiting on API keys',
          details: 'Blocked until third-party access is granted.',
        },
      ],
    },
    {
      title: 'Done',
      cards: [
        {
          title: 'Project kickoff meeting',
          details: 'Aligned on scope and timeline with stakeholders.',
        },
      ],
    },
  ],
};

/**
 * Opens the database, creating the file and applying the schema if needed, and
 * seeds the default user and board on first run.
 */
export function openDatabase(file = 'data/kanban.db') {
  if (file !== ':memory:') {
    fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  }

  const db = new DatabaseSync(file);

  // SQLite defaults foreign keys off, per connection, so the ON DELETE CASCADE
  // rules in the schema do nothing without this.
  db.exec('PRAGMA foreign_keys = ON');
  db.exec(fs.readFileSync(schemaPath, 'utf8'));

  seed(db);

  return db;
}

/** Runs work inside a transaction, rolling back if anything throws. */
export function transaction(db, work) {
  db.exec('BEGIN');
  try {
    const result = work();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function seed(db) {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM users').get();
  if (count > 0) return;

  transaction(db, () => {
    const { lastInsertRowid: userId } = db
      .prepare('INSERT INTO users (username) VALUES (?)')
      .run('user');

    const { lastInsertRowid: boardId } = db
      .prepare('INSERT INTO boards (user_id, name, subtitle) VALUES (?, ?, ?)')
      .run(userId, SEED_BOARD.name, SEED_BOARD.subtitle);

    const insertColumn = db.prepare(
      'INSERT INTO board_columns (id, board_id, title, position) VALUES (?, ?, ?, ?)',
    );
    const insertCard = db.prepare(
      'INSERT INTO cards (id, column_id, title, details, position) VALUES (?, ?, ?, ?, ?)',
    );

    SEED_BOARD.columns.forEach((column, columnPosition) => {
      const columnId = randomUUID();
      insertColumn.run(columnId, boardId, column.title, columnPosition);

      column.cards.forEach((card, cardPosition) => {
        insertCard.run(
          randomUUID(),
          columnId,
          card.title,
          card.details,
          cardPosition,
        );
      });
    });
  });
}
