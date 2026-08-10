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
- [x] Part 4: Fake user sign in
- [x] Part 5: Database modeling
- [x] Part 6: Backend
- [x] Part 7: Frontend + Backend
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

- [x] `POST /api/login` - validates credentials, sets the signed HttpOnly cookie
- [x] `POST /api/logout` - clears the cookie, returns 204
- [x] `GET /api/me` - returns `{ username }` or 401
- [x] `requireAuth` middleware, applied to `/api/me` now and to the board routes
      in Part 6. `health` and `login` stay open.
- [x] `SESSION_SECRET` read from the environment with a development fallback
- [x] Flutter `LoginScreen` using the project palette, with an error message on
      bad credentials
- [x] `AuthViewModel` holding the session state, checked on app start via
      `/api/me`
- [x] `main.dart` routes to `LoginScreen` or `BoardScreen` based on that state
- [x] Logout control in `_WebTopBar`. Both dead placeholder buttons were
      replaced by the username label and a "Log out" button.
- [x] Add `http` to `pubspec.yaml`. No extra credential handling is needed - the
      app and API share an origin, so the browser sends the cookie itself.

## Tests

- [x] Backend: login with correct credentials returns 200 and a `Set-Cookie`
      carrying HttpOnly and SameSite
- [x] Backend: login with wrong credentials, an unknown username, or no body at
      all returns 401 and no cookie
- [x] Backend: `/api/me` without a cookie returns 401
- [x] Backend: `/api/me` with the cookie from a login returns the username
- [x] Backend: cookies with a tampered signature, a tampered username, no
      signature, or a signature from a different secret are all rejected
- [x] Backend: logout clears the cookie and a follow-up `/api/me` returns 401
- [x] Backend: health stays reachable without a session
- [x] Flutter: `LoginScreen` shows an error on failed login
- [x] Flutter: successful login navigates to the board
- [x] Flutter: logout returns to the login screen
- [x] Flutter: empty fields are rejected before any request is made
- [x] `flutter test` 21/21, `npm test` 18/18

## Success criteria

- [x] Hitting `/` in a fresh browser session shows the login screen, not the
      board
- [x] `user` / `password` signs in; anything else shows an error. Both verified
      in a real browser against the container.
- [x] The session survives a page reload
- [x] Logout returns to the login screen, and a reload afterwards still shows
      login rather than the board
- [x] `curl` without a cookie returns 401 from the guarded routes. `/api/board`
      does not exist yet, so this was proved against `/api/me`; the board routes
      pick up the same middleware in Part 6.

## Notes

The cookie deliberately does not set `secure`, because the MVP runs over plain
HTTP on localhost and `secure` would stop the browser sending it at all. That
and the `dev-secret` fallback both need revisiting before this is ever served
over HTTPS.

Sign in only works when the app and the API share an origin, which is what the
container gives. Under `flutter run -d chrome` the app is served on a different
port, every API call becomes cross-origin, and the session cookie is not sent.
Test auth against the container.

---

# Part 5: Database modeling

Propose the relational schema, document it, get sign-off. No implementation in
this part.

## Checklist

- [x] `docs/database-schema.json` - the machine-readable proposal: tables,
      columns, types, nullability, foreign keys, indexes
- [x] `docs/DATABASE.md` - the rationale: why relational over a JSON blob, how
      card ordering works, how the AI's card-level operations map to writes,
      what is deliberately left out of the MVP
- [x] Tables: `users`, `boards`, `board_columns`, `cards`, `messages`.
      The column table is named `board_columns` rather than `columns`, which
      reads badly in SQL next to the keyword and matches the `BoardColumn`
      model.
- [x] Text ids for `board_columns` and `cards` so the ids are stable across the
      API, the frontend, and the AI
- [x] Integer `position` per column, contiguous from 0, for card ordering
- [x] Foreign keys with `ON DELETE CASCADE` from board to columns to cards
- [x] `messages` table for the chat history that Part 9 needs
- [x] Document the seed: one user `user`, one board, the 5 standard columns,
      and the 6 demo cards
- [x] User reviews and signs off

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

- [x] `backend/src/db/schema.sql` from the approved proposal, using
      `CREATE TABLE IF NOT EXISTS`
- [x] `backend/src/db/index.js` - `openDatabase(path)` opens via `node:sqlite`,
      sets `PRAGMA foreign_keys = ON`, applies the schema, seeds on first run
- [x] `DATABASE_PATH` env var, default `data/kanban.db`, directory created if
      absent
- [x] `createApp({ db })` takes the database handle so tests can pass `:memory:`
- [x] `backend/src/db/board.js` holds every board read and write, so Part 9 can
      apply the AI's operations through the same code the HTTP API uses
- [x] `GET /api/board` - board with columns and cards, ordered by position
- [x] `PATCH /api/columns/:id` - rename, rejects an empty title
- [x] `POST /api/cards` - create at the end of the column
- [x] `PATCH /api/cards/:id` - update title and details
- [x] `DELETE /api/cards/:id`
- [x] `POST /api/cards/:id/move` - `{ toColumnId, position }`, reindexes both
      affected columns inside a transaction
- [x] Every route scoped to the signed-in user's board - no cross-user access
- [x] Consistent errors: `res.status(n).json({ error })` via one catch-all

## Tests

- [x] `openDatabase` creates the file and its parent directory when missing
- [x] `openDatabase` on an existing database does not duplicate the seed
- [x] The seed creates 5 ordered columns and 6 cards, with opaque uuid ids
- [x] `GET /api/board` returns the seeded 5 columns in order with their cards
- [x] Rename a column, re-read the board, assert it persisted
- [x] Rename to an empty title returns 400 and changes nothing
- [x] Rename an unknown column returns 404
- [x] Create a card, assert it lands last in its column
- [x] Create with an empty title, or into an unknown column, returns 400
- [x] Update a card's title and details, and details alone
- [x] Delete a card, assert it is gone and remaining positions stay contiguous
- [x] Move a card to another column at index 0, assert order in both columns
- [x] Move a card within its column downward and upward, asserting the shift
- [x] Positions past the end and below zero clamp instead of failing
- [x] Move to a nonexistent column returns 400 and changes nothing
- [x] Operating on a nonexistent card id returns 404
- [x] Every board route returns 401 without a session cookie
- [x] Deleting a board cascades to its columns and cards
- [x] Foreign keys are enforced, and the message role check rejects bad roles
- [x] A card, column, or insert targeting another user's board answers 404/400
      and leaves their data untouched
- [x] `npm test` 46/46

## Success criteria

- [x] `npm test` in `backend/` passes with every case above
- [x] Deleting the database file and restarting recreates a working seeded
      database. Verified by removing the `kanban-data` volume and rebuilding.
- [x] Positions are contiguous from 0 in every column after any sequence of
      moves, asserted by `assertContiguous` after each ordering test
- [x] No route can read or write another user's board
- [x] Against the running container: a column rename and a new card both
      survived `stop.sh` then `start.sh`, and the seed did not re-run

## Notes

`position` on a move means the card's index in the destination column after the
move, and out of range values clamp. That matches what the Flutter drag code
already computes, including its decrement for same-column downward moves, so
Part 7 can send its existing index straight through.

The frontend is untouched in this part, so the browser still shows dummy data
and none of these routes are called yet. Part 7 connects them.

---

# Part 7: Frontend + Backend

The frontend uses the real API. The board becomes persistent.

## Checklist

- [x] `lib/data/board_repository.dart` - one class wrapping the board endpoints
- [x] `BoardViewModel` becomes an `AsyncNotifier`: loads from `GET /api/board`
      on build, calls the API on every mutation
- [x] Models gain `fromJson`, and `Board` carries `id`, `name`, `subtitle`
- [x] Loading and error states on `BoardScreen`, with a retry button
- [x] Column rename persists via `PATCH /api/columns/:id`
- [x] Card add, edit, delete, and move all persist
- [x] Mutations apply optimistically and revert if the call fails
- [x] `lib/widgets/board_action.dart` surfaces a failed mutation as a SnackBar,
      so a revert is explained rather than silent
- [x] `lib/data/dummy_data.dart` removed from the app, kept as
      `test/support/board_fixture.dart`
- [x] Board name and subtitle come from the API, not hardcoded strings

## Tests

- [x] Repository unit tests against a `MockClient` for each endpoint, asserting
      method, path, and body
- [x] Repository tests for error mapping and base-URI resolution
- [x] Viewmodel tests with a fake repository: load, add, edit, delete, move,
      and the same-column decrement in both directions
- [x] Viewmodel tests: a failed move, rename, delete, and add all revert
- [x] Viewmodel test: a failed load surfaces as an error state
- [x] Widget test: the board renders from a fake repository, and the old
      hardcoded strings and dummy cards are gone
- [x] Widget test: the loading spinner appears before data arrives
- [x] Widget test: the error state appears when the load fails, and retry works
- [x] Widget test: a failed mutation reverts and reports the failure
- [x] Backend integration test: one ordered lifecycle over HTTP - read, create,
      move, edit, rename, delete, each step reading back what the last wrote
- [x] `flutter test` 42/42, `npm test` 53/53

## Success criteria

- [x] Every board change survives a browser reload. A card dragged between
      columns in the browser was still there after a reload, and confirmed
      present in the SQLite file with contiguous positions.
- [x] Every board change survives `./scripts/stop.sh` then `./scripts/start.sh`.
      A column rename and a new card made in Part 6 came back after a full
      image rebuild, and the seed did not re-run.
- [x] No dummy data is reachable from the running app

## Notes

Riverpod 3 auto-disposes providers that have no listeners. This bit the tests:
`container.read(provider.future)` creates no listener, so the provider was torn
down mid-build and the future never completed. Tests now hold a
`container.listen`, and the failed-load test asserts on the `AsyncError` state
rather than the future, which never completes when the build throws. In the app
this behaviour is wanted - leaving the board screen disposes the provider, so
signing back in refetches instead of showing a stale board.

`addCard` is the one mutation that is not optimistic. The card id is assigned by
the backend, so inventing a temporary id locally would mean reconciling it
afterwards; a round trip before inserting is simpler and imperceptible from a
dialog.

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
