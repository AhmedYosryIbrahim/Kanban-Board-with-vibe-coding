import { Router } from 'express';

import { applyOperations } from '../ai/board-tools.js';
import { callOpenRouter } from '../ai/openrouter.js';
import { buildMessages } from '../ai/prompt.js';
import { boardResponseFormat, parseBoardResponse } from '../ai/schema.js';
import { getBoardForUser, readBoard } from '../db/board.js';
import { addMessage, readMessages } from '../db/messages.js';
import { fail } from '../fail.js';
import { requireAuth } from '../middleware/auth.js';

export function createChatRouter(db, { callAi = callOpenRouter } = {}) {
  const router = Router();

  router.use(requireAuth);

  router.use((req, res, next) => {
    req.board = getBoardForUser(db, req.username);
    next();
  });

  router.get('/chat', (req, res) => {
    res.json({ messages: readMessages(db, req.board.id) });
  });

  router.post('/chat', async (req, res) => {
    const message = (req.body?.message ?? '').trim();
    if (!message) fail(400, 'Message is required');

    const history = readMessages(db, req.board.id);
    const board = readBoard(db, req.board);

    const content = await callAi(buildMessages(board, history, message), {
      responseFormat: boardResponseFormat,
    });
    const { reply, operations } = parseBoardResponse(content);

    let finalReply = reply;
    let boardChanged = false;

    try {
      boardChanged = applyOperations(db, req.board, operations);
    } catch (error) {
      // The batch rolled back, so the board is untouched. Say so rather than
      // letting the model's optimistic reply stand.
      finalReply = `I was not able to update the board: ${error.message}`;
    }

    addMessage(db, req.board.id, 'user', message);
    addMessage(db, req.board.id, 'assistant', finalReply);

    res.json({ reply: finalReply, boardChanged });
  });

  return router;
}
