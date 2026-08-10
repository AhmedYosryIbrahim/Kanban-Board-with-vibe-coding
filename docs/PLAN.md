# Project Plan

Build order for the Project Management MVP described in `AGENTS.md`. Each part
is a checklist to be checked off as it is completed, with the tests that prove
it and the success criteria that close it.

Do not start a part until the previous part's success criteria are met.

## Locked decisions

Agreed before work started:

| Area | Decision |
| --- | --- |
| Database | Relational SQLite tables (users, boards, columns, cards, messages) with foreign keys. The schema proposal is written to `docs/database-schema.json` for sign-off. |
| Docker | Multi-stage build. Stage 1 pulls a Flutter SDK image and runs `flutter build web --release`; stage 2 is a slim Node image serving the output. |
| SQLite driver | `node:sqlite`, built into Node 22. No third-party driver. |
| Test runner | `node:test`, built into Node 22. No Jest or Vitest. |
| Auth | Signed `HttpOnly` cookie session. Middleware guards `/api`. `/api/logout` clears it. |
| AI updates | Card-level operations (create / update / move / delete / rename column) with ids, not whole-board replacement. |

Two items were found missing from the original outline and are folded in below:

- Card editing does not exist in the frontend at all. Added to Parts 3 and 7.
- Column rename persistence is not called out anywhere. Added to Parts 6 and 7.

## Target layout

```
Dockerfile
.dockerignore
.env                     gitignored, holds OPENROUTER_API_KEY
AGENTS.md
backend/                 Express API + static serving + SQLite + AI
docs/
  PLAN.md
  DATABASE.md
  database-schema.json
frontend/                Flutter web app
scripts/                 start/stop for Mac, Linux, Windows
```

## Progress

- [x] Part 1: Plan
- [x] Part 2: Scaffolding
- [x] Part 3: Add in Frontend
- [ ] Part 4: Fake user sign in
- [ ] Part 5: Database modeling
- [ ] Part 6: Backend
- [ ] Part 7: Frontend + Backend
- [ ] Part 8: AI connectivity
- [ ] Part 9: AI board updates
- [ ] Part 10: AI chat sidebar

---

# Part 1: Plan

Enrich this document with detailed substeps, tests, and success criteria, and
describe the existing code for future agents.

- [x] Survey the existing frontend code, tests, and toolchain versions
- [x] Resolve the open technical decisions with the user (see Locked decisions)
- [x] Write `frontend/AGENTS.md` describing the existing Flutter code
- [x] Write `backend/AGENTS.md` as the contract for the backend to be built
- [x] Write `scripts/AGENTS.md` as the contract for the start/stop scripts
- [x] Rewrite this document with per-part checklists, tests, and success criteria
- [x] User reviews and approves the plan

**Tests:** none, this part produces documents.

**Success criteria:** the user has read this document and approved it. No code
is written before that approval.

---

# Part 2: Scaffolding

Docker infrastructure, an Express backend that serves a placeholder page and one
API route, and the start/stop scripts. Proves the container, the port mapping,
and the scripts work before any real functionality exists.

## Checklist

- [x] `backend/package.json` with `"type": "module"`, `express`, and
      `start` / `test` scripts. `cookie-parser` deferred to Part 4, where it is
      first needed.
- [x] `backend/src/app.js` exporting `createApp()` - builds the Express app,
      does not listen
- [x] `backend/src/server.js` - reads `PORT`, calls `createApp()`, listens
- [x] `GET /api/health` returning `{ status: "ok" }`
- [x] Placeholder `index.html` served at `/` confirming the server is up
- [x] The placeholder page fetches `/api/health` and displays the result, so
      opening the page proves both static serving and the API in one look
- [x] `Dockerfile` - single stage for now, Node 22 slim base, `npm ci`,
      `CMD ["node", "src/server.js"]`, `EXPOSE 3000`
- [x] `.dockerignore` excluding `node_modules`, `.git`, `frontend/build`,
      `frontend/.dart_tool`, `.env`
- [x] `scripts/start.sh` and `scripts/stop.sh`, executable bit set
- [x] `scripts/start.bat` and `scripts/stop.bat`
- [x] Named volume `kanban-data` mounted at `/app/data` in the run command
- [x] `.gitignore` updated for `backend/node_modules` and `backend/data`

## Tests

- [x] `backend/test/health.test.js` - `createApp()`, request `/api/health`,
      assert 200 and the JSON body
- [x] `backend/test/health.test.js` - `/` serves the placeholder page as HTML
- [x] `backend/test/health.test.js` - an unknown `/api` path returns 404
- [x] `npm test` passes in `backend/` (3/3)

## Success criteria

- [x] `./scripts/start.sh` builds the image and starts the container with no
      manual steps
- [x] `http://localhost:3000` shows the placeholder page and both rows, static
      serving and the health result, read `ok` in a real browser
- [x] `curl http://localhost:3000/api/health` returns `{"status":"ok"}`
- [x] `./scripts/stop.sh` stops and removes the container, and running it twice
      in a row exits 0
- [x] `docker volume ls` shows `kanban-data` surviving a stop
- [x] `OPENROUTER_API_KEY` reaches the container environment via `--env-file`,
      which Part 8 depends on

## Notes

`.env` was written as `OPENROUTER_API_KEY = value`, with spaces around the `=`.
Docker's `--env-file` parser does not allow that and read the variable name as
`OPENROUTER_API_KEY ` with a trailing space. Fixed in `.env` itself rather than
by normalizing in the start script, since the file format was the root cause and
the standards rule out defensive workarounds. Keep `.env` as strict
`KEY=value` lines with no surrounding whitespace.

---

# Part 3: Add in Frontend

Build the Flutter web app into the image and serve it at `/`, replacing the
placeholder. Add the missing card editing. Comprehensive unit and integration
tests.

## Checklist

- [x] Convert the `Dockerfile` to multi-stage: stage 1 on
      `ghcr.io/cirruslabs/flutter:3.41.8` runs `flutter pub get` and
      `flutter build web --release`; stage 2 copies `build/web` into the Node
      image
- [x] Serve the Flutter bundle with `express.static`
- [x] SPA fallback: unmatched non-`/api` GET requests return `index.html`
- [x] JSON 404 catch-all mounted at `/api` so unknown API paths do not reach
      the SPA fallback
- [x] Delete the Part 2 placeholder page
- [x] Add `updateCard(columnId, cardId, title, details)` to `BoardViewModel`
- [x] Add `showEditCardDialog`. `add_card_dialog.dart` became `card_dialog.dart`
      with both dialogs over a shared `_CardDialog`
- [x] Wire an edit affordance on `CardWidget` next to the existing delete icon
- [x] Confirm the palette is applied and no new hardcoded hex values are added
      outside `AppColors`

## Tests

- [x] `flutter analyze` clean
- [x] Existing 8 Flutter tests still pass
- [x] New viewmodel tests: `updateCard` changes only the target card;
      `updateCard` on an unknown id is a no-op
- [x] New widget test: tapping edit opens the dialog prefilled, submitting
      updates the card text on the board
- [x] New widget test: an empty title is rejected by the edit dialog
- [x] New widget test: drag a card from one column to another and assert it
      moved (integration over `Draggable` / `DragTarget`)
- [x] Backend test: `GET /` serves the entry point, and a static asset is served
      from the bundle directory
- [x] Backend test: an unknown path such as `/some/client/route` returns
      `index.html`, but an unknown `/api/*` path returns JSON 404 for both GET
      and non-GET
- [x] `flutter test` 14/14, `npm test` 6/6

## Success criteria

- [x] `./scripts/start.sh` produces a container that serves the working Kanban
      demo at `http://localhost:3000`
- [x] Card edit verified in a real browser against the container: the dialog
      opens prefilled, the change lands on the board
- [x] No Flutter SDK is needed on the host to build or run the container
- [x] Data still resets on reload - persistence is Part 7

## Notes

The backend serving tests run against a small fixture bundle in
`backend/test/fixtures/web`, not against a real `flutter build web` output.
Requiring a Flutter build to run `npm test` would make the backend suite slow
and dependent on the Flutter toolchain, for no extra coverage - the behavior
under test is route order and static serving, which a two-file fixture exercises
exactly as well. The real bundle is verified in the browser instead.

`node --test` with no arguments treats every `.js` file under `test/` as a test
file and executed the fixture as test 1. The `test` script now passes an
explicit `test/**/*.test.js` glob.

---

# Part 4: Fake user sign in

Gate the board behind a login screen. Credentials hardcoded to `user` /
`password`. Session is a signed HttpOnly cookie.

## Checklist

- [ ] `POST /api/login` - validates credentials, sets the signed HttpOnly cookie
- [ ] `POST /api/logout` - clears the cookie, returns 204
- [ ] `GET /api/me` - returns `{ username }` or 401
- [ ] `requireAuth` middleware applied to `/api` except `health` and `login`
- [ ] `SESSION_SECRET` read from the environment with a development fallback
- [ ] Flutter `LoginScreen` using the project palette, with an error message on
      bad credentials
- [ ] `AuthViewModel` holding the session state, checked on app start via
      `/api/me`
- [ ] `main.dart` routes to `LoginScreen` or `BoardScreen` based on that state
- [ ] Logout control in `_WebTopBar`, replacing one of the dead placeholder
      buttons
- [ ] Add `http` to `pubspec.yaml` and send credentials with requests so the
      cookie is included

## Tests

- [ ] Backend: login with correct credentials returns 200 and a `Set-Cookie`
- [ ] Backend: login with wrong credentials returns 401 and no cookie
- [ ] Backend: `/api/me` without a cookie returns 401
- [ ] Backend: `/api/me` with the cookie from a login returns the username
- [ ] Backend: a tampered or unsigned cookie is rejected
- [ ] Backend: logout clears the cookie and a follow-up `/api/me` returns 401
- [ ] Flutter: `LoginScreen` shows an error on failed login
- [ ] Flutter: successful login navigates to the board
- [ ] Flutter: logout returns to the login screen

## Success criteria

- Hitting `/` in a fresh browser session shows the login screen, not the board
- `user` / `password` signs in; anything else shows an error
- The session survives a page reload
- Logout returns to the login screen and the board is not reachable afterwards
- `curl` against `/api/board` without a cookie returns 401

---

# Part 5: Database modeling

Propose the relational schema, document it, get sign-off. No implementation in
this part.

## Checklist

- [ ] `docs/database-schema.json` - the machine-readable proposal: tables,
      columns, types, nullability, foreign keys, indexes
- [ ] `docs/DATABASE.md` - the rationale: why relational over a JSON blob, how
      card ordering works, how the AI's card-level operations map to writes,
      what is deliberately left out of the MVP
- [ ] Tables: `users`, `boards`, `columns`, `cards`, `messages`
- [ ] Text ids for `columns` and `cards` so the ids are stable across the API,
      the frontend, and the AI
- [ ] Integer `position` per column, contiguous from 0, for card ordering
- [ ] Foreign keys with `ON DELETE CASCADE` from board to columns to cards
- [ ] `messages` table for the chat history that Part 9 needs
- [ ] Document the seed: one user `user`, one board, the 5 standard columns
- [ ] User reviews and signs off

## Tests

None - this part produces documents. The schema is exercised in Part 6.

## Success criteria

- The schema supports every operation in the Part 6 API table
- The schema supports multiple users and multiple boards even though the MVP
  seeds exactly one of each
- The user has signed off before Part 6 starts

---

# Part 6: Backend

Implement the database and the API routes that read and change the Kanban.
Thorough backend unit tests. The database is created if it does not exist.

## Checklist

- [ ] `backend/src/db/schema.sql` from the approved proposal, using
      `CREATE TABLE IF NOT EXISTS`
- [ ] `backend/src/db/index.js` - `openDatabase(path)` opens via `node:sqlite`,
      sets `PRAGMA foreign_keys = ON`, applies the schema, seeds on first run
- [ ] `DATABASE_PATH` env var, default `data/kanban.db`, directory created if
      absent
- [ ] `createApp(db)` takes the database handle so tests can pass `:memory:`
- [ ] `GET /api/board` - board with columns and cards, ordered by position
- [ ] `PATCH /api/columns/:id` - rename, rejects an empty title
- [ ] `POST /api/cards` - create at the end of the column
- [ ] `PATCH /api/cards/:id` - update title and details
- [ ] `DELETE /api/cards/:id`
- [ ] `POST /api/cards/:id/move` - `{ toColumnId, position }`, reindexes both
      affected columns inside a transaction
- [ ] Every route scoped to the signed-in user's board - no cross-user access
- [ ] Consistent errors: `res.status(n).json({ error })`

## Tests

- [ ] `openDatabase` creates the file when it does not exist
- [ ] `openDatabase` on an existing database does not duplicate the seed
- [ ] `GET /api/board` returns the seeded 5 columns in order
- [ ] Rename a column, re-read the board, assert it persisted
- [ ] Rename to an empty title returns 400
- [ ] Create a card, assert it lands last in its column
- [ ] Update a card's title and details
- [ ] Delete a card, assert it is gone and remaining positions stay contiguous
- [ ] Move a card to another column at index 0, assert order in both columns
- [ ] Move a card within its column downward, assert the off-by-one is handled
- [ ] Move to a nonexistent column returns 400
- [ ] Operating on a nonexistent card id returns 404
- [ ] Every mutating route returns 401 without a session cookie
- [ ] Deleting a board cascades to its columns and cards

## Success criteria

- `npm test` in `backend/` passes with every case above
- Deleting `data/kanban.db` and restarting recreates a working seeded database
- Positions are contiguous from 0 in every column after any sequence of moves
- No route can read or write another user's board

---

# Part 7: Frontend + Backend

The frontend uses the real API. The board becomes persistent.

## Checklist

- [ ] `lib/data/board_repository.dart` - one class wrapping the board endpoints
- [ ] `BoardViewModel` becomes async: loads from `GET /api/board` on build,
      calls the API on every mutation
- [ ] Loading and error states on `BoardScreen`
- [ ] Column rename persists via `PATCH /api/columns/:id`
- [ ] Card add, edit, delete, and move all persist
- [ ] Drag and drop sends the move, and reverts the local state if the call fails
- [ ] Delete `lib/data/dummy_data.dart` from the app path, or keep it only as
      test fixture data
- [ ] Board name and subtitle come from the API, not hardcoded strings

## Tests

- [ ] Repository unit tests against a mocked HTTP client for each endpoint
- [ ] Viewmodel tests with a fake repository: load, add, edit, delete, move
- [ ] Viewmodel test: a failed move reverts the optimistic local change
- [ ] Widget test: the board renders from a fake repository, not dummy data
- [ ] Widget test: the loading state appears before data arrives
- [ ] Widget test: the error state appears when the load fails
- [ ] Backend integration test: full lifecycle over HTTP - login, read board,
      add a card, move it, edit it, delete it, confirm each read-back

## Success criteria

- Every board change survives a browser reload
- Every board change survives `./scripts/stop.sh` then `./scripts/start.sh`,
  proving the `kanban-data` volume works
- Two browser tabs signed in as the same user both show a change after reload
- No dummy data is reachable from the running app

---

# Part 8: AI connectivity

Prove the OpenRouter call works, nothing more.

## Checklist

- [ ] `backend/src/ai/openrouter.js` - `callOpenRouter(messages)` against
      `https://openrouter.ai/api/v1/chat/completions` using global `fetch`
- [ ] Model `openai/gpt-oss-120b`
- [ ] `OPENROUTER_API_KEY` read from the environment, never logged, never sent
      to the frontend
- [ ] Clear error when the key is missing or the call fails
- [ ] Confirm the key reaches the container via `--env-file .env`
- [ ] A temporary connectivity check asking "what is 2+2"

## Tests

- [ ] Unit test with a stubbed `fetch`: the request carries the right model,
      auth header, and message shape
- [ ] Unit test: a missing key produces a clear error and no network call
- [ ] Unit test: a non-200 response from OpenRouter surfaces as a clear error
- [ ] A live connectivity check, run manually, that asks "what is 2+2" and
      asserts the answer contains "4". Not part of `npm test` - the automated
      suite must never depend on the network or spend tokens.

## Success criteria

- The live check returns 4 from inside the running container
- `npm test` passes with no network access
- The key does not appear in any log line or any HTTP response

---

# Part 9: AI board updates

Extend the AI call to always include the board JSON, the user's question, and
the conversation history, and to return Structured Outputs carrying a reply and
optional board operations.

## Checklist

- [ ] System prompt explaining the board, the column ids, and the available
      operations
- [ ] Every call includes the current board JSON and the stored conversation
      history
- [ ] Strict Structured Outputs JSON schema:
      `{ reply: string, operations: [...] }`
- [ ] Operation types: `create_card`, `update_card`, `move_card`, `delete_card`,
      `rename_column` - each carrying the ids it needs
- [ ] `backend/src/ai/board-tools.js` applies operations to the database,
      reusing the Part 6 logic
- [ ] Operations applied in one transaction - all or nothing
- [ ] Operations referencing unknown ids are rejected without applying anything,
      and the reply says so
- [ ] `POST /api/chat` persists both the user message and the reply to
      `messages` and returns `{ reply, boardChanged }`

## Tests

- [ ] Schema unit test: a valid model response parses; a malformed one is
      rejected with a clear error
- [ ] `board-tools` unit tests, one per operation type, asserting the database
      state afterwards
- [ ] Multiple operations in one response all apply
- [ ] One invalid operation in a batch rolls back the whole batch
- [ ] An unknown card id is rejected without a partial write
- [ ] `POST /api/chat` with a stubbed AI returns the reply and sets
      `boardChanged` correctly for both a chatty response and an acting one
- [ ] Conversation history is persisted and included in the next call
- [ ] `POST /api/chat` returns 401 without a session

## Success criteria

- With a live key, "add a card called Deploy to staging in the To Do column"
  creates exactly that card, and `GET /api/board` shows it
- "what is on my board" answers without changing anything and reports
  `boardChanged: false`
- A conversational follow-up such as "move that one to Done" resolves the
  reference using history
- The automated suite still passes with no network access

---

# Part 10: AI chat sidebar

The chat UI, with automatic board refresh when the AI changes something.

## Checklist

- [ ] `lib/widgets/chat_sidebar.dart` - collapsible right sidebar using the
      project palette
- [ ] `ChatViewModel` holding the message list and the sending state
- [ ] Message bubbles distinguishing user and assistant
- [ ] Multiline input, Enter to send, Shift+Enter for a newline
- [ ] Pending indicator while awaiting the reply
- [ ] Error message in the thread when the call fails, with the input preserved
- [ ] On `boardChanged: true`, invalidate the board provider so the board
      refreshes with no user action
- [ ] Board layout adapts when the sidebar opens - the columns stay usable
- [ ] Sidebar collapses on narrow viewports

## Tests

- [ ] Chat viewmodel: sending appends the user message then the reply
- [ ] Chat viewmodel: a failed send surfaces an error and keeps the input
- [ ] Chat viewmodel: `boardChanged: true` triggers the board reload
- [ ] Widget test: typing and submitting renders both bubbles
- [ ] Widget test: the pending indicator shows while the call is in flight
- [ ] Widget test: the sidebar opens and closes
- [ ] Widget test: a board change from chat updates the visible columns
- [ ] `flutter analyze` clean, full Flutter and backend suites pass

## Success criteria

- Asking the AI to create, move, or rename in the sidebar updates the board on
  screen with no manual refresh
- The change persists across a reload
- The chat thread survives a reload, loaded from `messages`
- The full app works end to end from `./scripts/start.sh` on a clean machine
  with only Docker and a `.env` file
