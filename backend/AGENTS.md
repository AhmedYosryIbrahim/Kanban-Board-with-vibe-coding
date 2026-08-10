# Backend (Node.js + Express)

Serves the built Flutter web app at `/` and the JSON API under `/api`. Owns the
SQLite database and the OpenRouter AI calls.

Status: the whole backend is implemented, including the AI chat endpoint. Only
the Flutter chat sidebar (Part 10) is outstanding, and it needs no backend
changes.

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
      messages.js        chat history read and append
    middleware/
      auth.js            requireAuth - rejects unauthenticated /api requests
    routes/
      auth.js            login, logout, me
      board.js           thin HTTP layer over db/board.js
      chat.js            AI chat
    ai/
      openrouter.js      callOpenRouter(messages, { responseFormat })
      schema.js          boardResponseFormat + parseBoardResponse
      prompt.js          buildMessages(board, history, message)
      board-tools.js     applyOperations - applies AI operations to the database
  scripts/
    check-ai.js          live OpenRouter check, run by hand
  test/
    *.test.js            node:test, one file per route module or unit
    support/             shared test harness
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
| GET | `/api/chat` | - | `{ messages }`, oldest first |
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

OpenRouter, model `openai/gpt-oss-120b`, key from `OPENROUTER_API_KEY`.

`ai/openrouter.js` exports `callOpenRouter(messages, { responseFormat })`,
which returns the assistant's message content as a string. It reads the key at
call time rather than at import, so a missing key does not stop the rest of the
server from starting, and it throws before making any request when the key is
absent.

The call uses Structured Outputs with a strict JSON schema, passed as
`responseFormat`. The model receives the current board JSON, the conversation
history, and the user's message, and returns a reply plus zero or more
card-level operations. Operations are applied server-side in `board-tools.js`,
never by the client.

### The response contract

`ai/schema.js` owns both the schema and `parseBoardResponse`. Strict Structured
Outputs requires every property to appear in `required` and forbids extra ones,
so fields that only apply to some operations are declared nullable and the model
sends `null` where they do not apply. `parseBoardResponse` still validates: the
response is remote input, and nothing downstream should assume it is well
formed.

### Applying operations

`applyOperations(db, board, operations)` wraps the batch in one transaction and
routes each operation through the same `db/board.js` functions the HTTP API
uses. Two consequences worth keeping:

- The AI cannot reach data the user could not reach themselves, and ownership
  checks are not written twice.
- One bad operation aborts the whole batch. The route catches that, replaces the
  model's optimistic reply with `I was not able to update the board: ...`, and
  returns `boardChanged: false`. Letting "Done, I moved it" stand over a board
  that did not change would be worse than an error.

`transaction` in `db/index.js` is re-entrant for exactly this reason: SQLite
rejects a `BEGIN` inside a `BEGIN`, and the per-operation functions already open
their own. A nested call just runs the work and lets the outermost transaction
decide, which is what makes a batch all-or-nothing.

### The prompt

`ai/prompt.js` builds the message list and caps replayed history at
`HISTORY_LIMIT` (20), so a long conversation cannot grow the request without
bound.

The prompt must spell out that **the server assigns new card ids**. An earlier
version said only "never invent an id", and the model refused to create cards at
all, reasoning that `create_card` needed an id it was not allowed to make up. If
you tighten the id rules, re-run the live checks below.

Never log the API key. Never send the key to the frontend. Failures surface as
`OpenRouter request failed (<status>)` with no body echoed, because OpenRouter
error bodies can repeat the request.

### Live check

`npm test` must never touch the network or spend tokens, so the automated tests
stub `fetch`. The real call is a separate manual script:

```
npm run check:ai
```

It asks the model what 2+2 is and fails unless the answer contains 4. It reads
the repo-root `.env` through `--env-file-if-exists`.

Chat behaviour cannot be unit tested against the real model either. The
automated tests stub the AI through `createApp({ callAi })`. After changing the
prompt or the schema, exercise these against the running container by hand:

- a read-only question, expecting `boardChanged: false` and no board change
- "add a card called X in the Y column", expecting exactly that card
- a follow-up such as "move that one to Done", which only works if history is
  being replayed
- a multi-operation request, such as renaming a column and adding two cards

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
