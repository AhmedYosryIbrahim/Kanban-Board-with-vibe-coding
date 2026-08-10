import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);

createApp({ staticDir: process.env.STATIC_DIR }).listen(port, () => {
  console.log(`Kanban server listening on http://localhost:${port}`);
});
