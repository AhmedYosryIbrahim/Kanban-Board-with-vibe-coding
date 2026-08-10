import cookieParser from 'cookie-parser';
import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { authRouter } from './routes/auth.js';
import { createBoardRouter } from './routes/board.js';

const defaultStaticDir = fileURLToPath(new URL('../public', import.meta.url));

/**
 * Builds the Express app without listening, so tests can drive it directly.
 */
export function createApp({
  db,
  staticDir = defaultStaticDir,
  sessionSecret = 'dev-secret',
} = {}) {
  const app = express();

  app.use(express.json());
  app.use(cookieParser(sessionSecret));

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/api', authRouter);

  if (db) {
    app.use('/api', createBoardRouter(db));
  }

  // Unknown API routes answer as JSON. Without this they would fall through to
  // the SPA handler below and return the Flutter page with a 200.
  app.use('/api', (req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  // Routes signal failures by throwing an Error carrying a status.
  app.use('/api', (error, req, res, next) => {
    res.status(error.status ?? 500).json({ error: error.message });
  });

  app.use(express.static(staticDir));

  app.get('/*splat', (req, res) => {
    res.sendFile(path.join(staticDir, 'index.html'));
  });

  return app;
}
