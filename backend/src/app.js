import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const defaultStaticDir = fileURLToPath(new URL('../public', import.meta.url));

/**
 * Builds the Express app without listening, so tests can drive it directly.
 */
export function createApp({ staticDir = defaultStaticDir } = {}) {
  const app = express();

  app.use(express.json());

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  // Unknown API routes answer as JSON. Without this they would fall through to
  // the SPA handler below and return the Flutter page with a 200.
  app.use('/api', (req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  app.use(express.static(staticDir));

  app.get('/*splat', (req, res) => {
    res.sendFile(path.join(staticDir, 'index.html'));
  });

  return app;
}
