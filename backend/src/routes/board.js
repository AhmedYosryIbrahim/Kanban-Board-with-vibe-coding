import { Router } from 'express';

import {
  createCard,
  deleteCard,
  getBoardForUser,
  moveCard,
  readBoard,
  renameColumn,
  updateCard,
} from '../db/board.js';
import { requireAuth } from '../middleware/auth.js';

export function createBoardRouter(db) {
  const router = Router();

  router.use(requireAuth);

  // Every route works from the signed in user's board, never a client-supplied
  // board id, so one user cannot reach another user's data.
  router.use((req, res, next) => {
    req.board = getBoardForUser(db, req.username);
    next();
  });

  router.get('/board', (req, res) => {
    res.json(readBoard(db, req.board));
  });

  router.patch('/columns/:id', (req, res) => {
    res.json(renameColumn(db, req.board, req.params.id, req.body?.title));
  });

  router.post('/cards', (req, res) => {
    const { columnId, title, details } = req.body ?? {};
    res.status(201).json(createCard(db, req.board, columnId, title, details));
  });

  router.patch('/cards/:id', (req, res) => {
    res.json(updateCard(db, req.board, req.params.id, req.body ?? {}));
  });

  router.delete('/cards/:id', (req, res) => {
    deleteCard(db, req.board, req.params.id);
    res.status(204).end();
  });

  router.post('/cards/:id/move', (req, res) => {
    const { toColumnId, position } = req.body ?? {};
    moveCard(db, req.board, req.params.id, toColumnId, position);
    res.json(readBoard(db, req.board));
  });

  return router;
}
