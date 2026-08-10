# Backend (Node.js + Express)

Serves the built Flutter web app at `/` and the JSON API under `/api`. Owns the
SQLite database and the OpenRouter AI calls.

Status: static serving, sessions, the database, and the board routes are
implemented. The AI section below is the contract that Parts 8-9 of
`docs/PLAN.md` build against.

## Toolchain

- Node 22 (`node:sqlite` and `node:test` are built in - do not add a SQLite
  driver or a test runner as dependencies)
- npm as the package manager
- ESM only (`"type": "module"` in `package.json`)
- Dependencies limited to: `express` (and `cookie-parser` from Part 4)

## Commands

Run from `backend/`:

```
npm install
npm start
npm test
```

## Layout

```
backend/
  package.json
  src/
    server.js            reads env, calls createApp, listens
    app.js               createApp({ staticDir, db }) - builds the express app, no listen
    db/
      index.js           openDatabase(path), transaction(db, work)
      schema.sql         table definitions
      board.js           every read and write against a board
    middleware/
      auth.js            requireAuth - rejects unauthenticated /api requests
    routes/
      auth.js            login, logout, me
      board.js           thin HTTP layer over db/board.js
      chat.js            AI chat
    ai/
      openrouter.js      callOpenRouter(messages, schema)
      board-tools.js     applies AI operations to the database
  test/
    *.test.js            node:test, one file per route module or unit
    fixtures/web/        stand-in static bundle for the serving tests
```

`app.js` exports a `createApp(options)` factory that returns the Express app
without listening; `server.js` is the only place that binds a port. This split
is what makes the API testable. From Part 6 the factory also takes an
already-open database handle so tests can pass `:memory:`.

Only `test/**/*.test.js` runs as a test. The `test` script says so explicitly
because a bare `node --test` treats every `.js` file under `test/` as a test
file and would execute the fixtures.

## API surface

All routes under `/api` except `/api/health` and `/api/login` require a valid
session cookie and return 401 otherwise.

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| GET | `/api/health` | - | `{ status: "ok" }` |
| POST | `/api/login` | `{ username, password }` | `{ username }`, sets cookie |
| POST | `/api/logout` | - | 204, clears cookie |
| GET | `/api/me` | - | `{ username }` |
| GET | `/api/board` | - | full board JSON |
| PATCH | `/api/columns/:id` | `{ title }` | updated column |
| POST | `/api/cards` | `{ columnId, title, details }` | 201, created card |
| PATCH | `/api/cards/:id` | `{ title?, details? }` | updated card |
| DELETE | `/api/cards/:id` | - | 204 |
| POST | `/api/cards/:id/move` | `{ toColumnId, position }` | the whole board |
| POST | `/api/chat` | `{ message }` | `{ reply, boardChanged }` |

`position` on a move is the card's index in the destination column **after** the
move. Out of range values clamp rather than fail, so a drop past the end of a
column lands at the end. This matches what the Flutter drag code already
computes, including its decrement for same-column downward moves.

The board JSON returned by `GET /api/board` matches the shape the Flutter
models expect:

```json
{
  "id": 1,
  "name": "Product Roadmap",
  "columns": [
    {
      "id": "todo",
      "title": "To Do",
      "cards": [{ "id": "c1", "title": "...", "details": "..." }]
    }
  ]
}
```

Column and card ids are text, not autoincrement integers, so the ids the AI
sees and returns are stable and match the frontend.

## Auth

MVP credentials are hardcoded to `user` / `password`, checked in the login
route. On success the route sets a signed `HttpOnly` cookie named
`kanban_session` holding the username; `requireAuth` reads it and attaches
`req.username`. `SESSION_SECRET` comes from the environment with a development
fallback. There is no password column and no hashing in the MVP - the `users`
table exists so multiple users are possible later.

cookie-parser sets a signed cookie to `false` when the signature does not
verify, so a tampered cookie fails the same falsy check as a missing one and
`requireAuth` needs no special case for it.

`secure` is deliberately not set on the cookie, because the MVP runs over plain
HTTP on localhost. Setting it would stop the cookie being sent at all. Revisit
before this is ever served over HTTPS, along with the `dev-secret` fallback.

## Database

SQLite via `node:sqlite`. The file path comes from `DATABASE_PATH`, defaulting
to `data/kanban.db`. `openDatabase` creates the file and applies `schema.sql`
with `CREATE TABLE IF NOT EXISTS` if it does not exist, then seeds the default
user and their board with the 5 standard columns. Foreign keys are on
(`PRAGMA foreign_keys = ON`).

Card ordering is an integer `position` per column, contiguous from 0.
Moves reindex the affected columns inside a transaction. See `docs/DATABASE.md`
for the full schema and rationale.

All board reads and writes live in `db/board.js`, not in the route handlers, so
Part 9 can apply the AI's operations through exactly the same code the HTTP API
uses. Every function there takes the board resolved from the session, so a
column or card belonging to someone else answers 404 rather than being touched.

## AI

OpenRouter, model `openai/gpt-oss-120b`, key from `OPENROUTER_API_KEY`. Calls
use Structured Outputs with a strict JSON schema so the response always parses.
The model receives the current board JSON, the conversation history, and the
user's message, and returns a reply plus zero or more card-level operations.
Operations are applied server-side in `board-tools.js`, never by the client.

Never log the API key. Never send the key to the frontend.

## Environment

Read from the process environment, loaded from the repo-root `.env` (gitignored)
by the start scripts or `--env-file`:

- `OPENROUTER_API_KEY` - required for `/api/chat`
- `PORT` - default 3000
- `DATABASE_PATH` - default `data/kanban.db`
- `SESSION_SECRET` - default `dev-secret`
- `STATIC_DIR` - overrides the served bundle, default `../public` next to `src`

## Static serving

`express.static` over the Flutter `build/web` output, which stage 2 of the root
`Dockerfile` copies to `/app/public`. Any unmatched non-`/api` GET falls back to
`index.html` so client-side routes work.

Route order matters and is load-bearing: the API routes come first, then a
JSON 404 catch-all mounted at `/api`, then the static handler, then the SPA
fallback. Without the `/api` catch-all an unknown API path would reach the
fallback and return the Flutter page with a 200, which is much harder to debug
from the client than a 404.

There is no `public/` directory in the repo - it exists only inside the image.
To run the server against a real bundle outside Docker, build the frontend and
point at it:

```
cd frontend && flutter build web --release
cd ../backend && STATIC_DIR=../frontend/build/web npm start
```

## Conventions

- No TypeScript, no build step, no transpiler.
- Errors: `res.status(n).json({ error: "message" })`. Data functions call
  `fail(status, message)` in `db/board.js`, which throws a plain `Error` with a
  `status` property; the single catch-all in `app.js` turns it into that JSON
  shape. No custom error classes, no other error middleware.
- Validate only what the route actually needs. No schema validation library.
- Every route gets a `node:test` case covering the success path and its main
  failure path. Use `node:test`'s built-in assertions and Node's global `fetch`
  against an ephemeral port, or supertest-free direct app invocation.
- No emojis anywhere.
