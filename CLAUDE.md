# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A single-board Kanban project management app: Flutter web frontend, Node.js/Express backend, SQLite storage, and an AI chat sidebar (via OpenRouter) that can create/edit/move/delete cards and rename columns. MVP scope: one hardcoded user (`user`/`password`), one board per user, runs locally in Docker. Full business requirements and locked technical decisions are in `AGENTS.md`; the part-by-part build history and rationale for past decisions are in `docs/PLAN.md`.

Each area has its own `AGENTS.md` with far more detail than this file — read it before working in that directory:
- `backend/AGENTS.md` — full API table, auth, DB, AI integration, conventions
- `frontend/AGENTS.md` — architecture, state model, drag-and-drop, theming, test harness
- `scripts/AGENTS.md` — start/stop script contract
- `docs/DATABASE.md` — schema rationale (why relational, id scheme, ordering, what's deliberately omitted)

## Commands

Backend (run from `backend/`):
```
npm install
npm start          # node src/server.js
npm test           # node --test "test/**/*.test.js" — network-free, fetch is stubbed
npm run check:ai    # live OpenRouter call, run by hand, reads repo-root .env
```

Frontend (run from `frontend/`):
```
flutter pub get
flutter run -d chrome     # board/layout work only — see Auth caveat below
flutter test
flutter analyze
flutter build web --release   # writes to build/web, served by backend at /
```

Whole app, from repo root (Docker):
```
./scripts/start.sh   # builds image, runs container on :3000, needs .env at repo root
./scripts/stop.sh
```

Run backend against a real Flutter build without Docker:
```
cd frontend && flutter build web --release
cd ../backend && STATIC_DIR=../frontend/build/web npm start
```

Run a single backend test file: `node --test test/board.test.js` (from `backend/`).
Run a single Flutter test file: `flutter test test/viewmodels/board_view_model_test.dart`.

## Architecture

**Request flow:** Flutter web app (built to static files) is served by Express at `/`; all data goes through `/api/*`, backed by SQLite. `backend/src/app.js` exports `createApp({ staticDir, db, callAi? })` — builds the Express app without listening, which is what makes it testable (tests pass `:memory:` db and a stubbed AI). `backend/src/server.js` is the only place that binds a port.

**Route order is load-bearing:** API routes → JSON 404 catch-all mounted at `/api` → static handler → SPA fallback (`index.html` for unmatched non-`/api` GETs). Without the `/api` catch-all, unknown API paths would fall through to the SPA fallback and return a misleading 200.

**Auth:** signed HttpOnly cookie (`kanban_session`), checked by `requireAuth` middleware on all `/api` routes except `/api/health` and `/api/login`. No password hashing in the MVP — credentials are hardcoded constants. Sign-in only works when frontend and backend share an origin (i.e., through Docker/the built bundle) — `flutter run -d chrome` serves on a different port, making API calls cross-origin, so the session cookie won't be sent. Test auth against the running container.

**Database:** SQLite via Node's built-in `node:sqlite` (no third-party driver). All board reads/writes live in `backend/src/db/board.js`, never in route handlers directly — this lets the AI apply operations (`backend/src/ai/board-tools.js`) through the exact same code path as the HTTP API, so ownership checks aren't duplicated. Column and card ids are TEXT uuids (stable across API/frontend/AI round trips); user/board ids are integers. Card `position` is a contiguous integer per column, reindexed inside a transaction on every move — `transaction()` in `db/index.js` is deliberately re-entrant since SQLite rejects nested `BEGIN` and per-operation functions already open their own.

**AI chat:** `POST /api/chat` sends the full board JSON + capped conversation history (`HISTORY_LIMIT`=20) + user message to OpenRouter (`openai/gpt-oss-120b`) using Structured Outputs (strict JSON schema in `backend/src/ai/schema.js`). The model returns `{ reply, operations }`; operations are card-level (`create_card`/`update_card`/`move_card`/`delete_card`/`rename_column`), applied in one transaction — one bad operation rolls back the whole batch, and the route replaces the model's reply with an explicit "I was not able to update the board" rather than let an optimistic reply stand over an unchanged board. `GET/POST /api/chat` persist history to the `messages` table so a conversation survives reload.

**Frontend (MVVM + Riverpod):** repositories wrap HTTP (`lib/data/`), viewmodels own state via `AsyncNotifier` and call repositories (`lib/viewmodels/`), widgets call viewmodels only — never repositories directly (`lib/views/`, `lib/widgets/`). `BoardViewModel` applies mutations optimistically (update local state, call backend, revert + rethrow on failure) except `addCard`, which is not optimistic because the backend assigns the id. `runBoardAction` in the widget layer catches reverts and shows a SnackBar. `ChatViewModel.send`, on `boardChanged: true` from the backend, calls `ref.invalidate(boardViewModelProvider)` — that invalidation is the entire mechanism behind the board refreshing after an AI edit. Riverpod 3 auto-disposes providers with no listeners (intentional — leaving the board screen refetches on return) — in tests this means holding a `container.listen` for the test's lifetime, and asserting on `AsyncError` state rather than `provider.future` when a build fails.

**Drag and drop:** built on Flutter's own `Draggable`/`DragTarget`, no package. `ColumnWidget._calculateInsertIndex` measures each card's `RenderBox` via per-card `GlobalKey`s to find the hover index.

**Docker build:** multi-stage — stage 1 (`ghcr.io/cirruslabs/flutter:3.41.8`) runs `flutter build web --release`; stage 2 (`node:22-slim`) copies that output to `/app/public` and runs the Express server. No Flutter SDK needed on the host to build or run the container. The named volume `kanban-data` (mounted at `/app/data`) is what makes the SQLite file survive a container rebuild — `stop.sh` never touches it.

## Coding standards

(From `AGENTS.md`, project-wide.)

1. Use latest versions of libraries and idiomatic approaches as of today.
2. Keep it simple — never over-engineer, no unnecessary defensive programming, no extra features beyond what's asked.
3. Be concise. No emojis, ever, anywhere (code, docs, scripts, commit messages).
4. When hitting issues, identify root cause before fixing. Don't guess — prove with evidence, then fix the root cause, not a symptom. (E.g., a malformed `.env` was fixed in the file, not papered over with defensive parsing in the start script.)
5. Backend: no TypeScript, no build step/transpiler, no schema validation library — validate only what a route actually needs. Errors are `res.status(n).json({ error })` via a single catch-all; data functions throw via `fail(status, message)` in `db/board.js`.
6. Frontend: don't hardcode hex colors in widgets — add them to `lib/theme/app_colors.dart` (a few pre-existing one-off greys in `board_screen.dart`/`column_widget.dart` are noted debt, not a pattern to extend).
7. Every backend route needs a `node:test` case for its success path and main failure path.
