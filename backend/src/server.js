import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);

const app = createApp({
  staticDir: process.env.STATIC_DIR,
  sessionSecret: process.env.SESSION_SECRET,
});

app.listen(port, () => {
  console.log(`Kanban server listening on http://localhost:${port}`);
});
