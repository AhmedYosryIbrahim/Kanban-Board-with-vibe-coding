# Frontend (Flutter web)

Flutter web app for the Kanban board. Package name `kanban_frontend`. Every
board change goes through the backend API and is persisted in SQLite; the app
ships no dummy data. An assistant sidebar talks to the AI and refreshes the
board when the AI changes it.

In Docker the release bundle is built by stage 1 of the root `Dockerfile` and
served by the backend at `/`.

## Toolchain

- Flutter 3.41.8 stable, Dart SDK `^3.11.5`
- Dependencies: `flutter_riverpod` ^3.3.2, `http` ^1.5.0, `uuid` ^4.6.0,
  `cupertino_icons`
- Dev: `flutter_test`, `flutter_lints` ^6.0.0 (via `analysis_options.yaml`)

## Commands

```
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
flutter build web --release
```

`flutter build web --release` writes to `build/web`, which the backend serves as
static files at `/`.

## Architecture

MVVM with Riverpod. Repositories wrap HTTP, viewmodels own state and call them,
widgets call viewmodels. Widgets never talk to a repository directly.

```
lib/
  main.dart                       ProviderScope + MaterialApp, routes on auth state
  data/
    auth_repository.dart          AuthRepository, AuthException, provider
    board_repository.dart         BoardRepository, BoardException, provider
    chat_repository.dart          ChatRepository, ChatException, provider
  viewmodels/
    auth_view_model.dart          AuthViewModel + authViewModelProvider
  views/
    login_screen.dart             LoginScreen
  models/
    board.dart                    Board { id, name, subtitle, List<BoardColumn> columns }
    chat_message.dart             ChatMessage, ChatRole, ChatReply
    board_column.dart             BoardColumn { id, title, List<CardItem> cards }
    card_item.dart                CardItem { id, title, details }
  viewmodels/
    board_view_model.dart         BoardViewModel + boardViewModelProvider
    chat_view_model.dart          ChatViewModel, ChatState, chatOpenProvider
  views/
    board_screen.dart             BoardScreen, _BoardBody, _BoardError, _WebTopBar
  widgets/
    column_widget.dart            ColumnWidget (title edit, drop target, insert indicator)
    card_widget.dart              CardWidget, _CardContent, DraggedCard payload
    card_dialog.dart              showAddCardDialog, showEditCardDialog, shared _CardDialog
    board_action.dart             runBoardAction - reports a failed mutation
    chat_sidebar.dart             ChatSidebar, message bubbles, composer
  theme/
    app_colors.dart               AppColors palette
    app_theme.dart                AppTheme.light
```

All models are immutable with `copyWith`. `BoardViewModel` never mutates in
place; every method rebuilds `state` from list comprehensions.

## Auth

`AuthViewModel extends AsyncNotifier<String?>` holds the signed in username, or
null when signed out. The session is an HttpOnly cookie the browser owns, so
`build()` has to ask `GET /api/me` whether one exists - the app cannot read the
cookie itself. `main.dart` watches it and shows `LoginScreen`, `BoardScreen`, or
a spinner accordingly. A failed session check falls through to `LoginScreen`.

`signIn` throws `AuthException` on rejected credentials rather than putting the
provider into an error state, so `LoginScreen` can show the message inline while
staying usable.

The app is served from the same origin as the API, so the browser attaches the
session cookie by itself and `AuthRepository` never touches it. This only holds
under Docker. Running `flutter run -d chrome` serves the app from a different
port, which makes every API call cross-origin: the cookie will not be sent and
sign in will not work without adding CORS and `withCredentials`. Test against
the container.

`AuthRepository` resolves paths against `Uri.base` so it works wherever the app
is served from. Tests inject a base URI, since `Uri.base` in the Dart VM is a
`file://` path.

## State model

`BoardViewModel extends AsyncNotifier<Board>`, exposed as
`boardViewModelProvider`. `build()` fetches `GET /api/board`, so the screen
renders loading, error, and data states straight from the provider.

Mutations apply to local state first and call the backend after, so the UI
responds immediately. If the call fails, `_apply` restores the previous board
and rethrows; `runBoardAction` in the widget layer catches that and shows a
SnackBar. The board visibly snaps back and the message says why.

- `renameColumn(columnId, newTitle)`
- `addCard(columnId, title, details)` - the one exception to the optimistic
  pattern: it calls the backend first, because the card id is assigned there
- `updateCard(columnId, cardId, title, details)`
- `deleteCard(columnId, cardId)`
- `moveCard({cardId, fromColumnId, toColumnId, targetIndex})` - handles both
  cross-column moves and same-column reordering. For same-column moves the
  target index is decremented when moving downward, because the card is removed
  before reinsertion. The decremented value is what goes to the API, which
  defines `position` as the index after the move.
- `refresh()` - refetches, for Part 10 when the AI changes the board

### Riverpod 3 auto-disposes by default

Providers with no listeners are torn down. Two consequences worth knowing:

- In the app, leaving `BoardScreen` disposes the board provider, so signing out
  and back in refetches rather than showing a stale board. That is wanted.
- In tests, `container.read(provider.future)` does **not** create a listener, so
  the provider can be disposed mid-build ("disposed during loading state, yet no
  value could be emitted"). Hold a `container.listen` for the test's lifetime.
  When the build fails, `provider.future` never completes at all - assert on the
  `AsyncError` state instead, which is what the UI renders anyway.

## Chat

`ChatViewModel extends AsyncNotifier<ChatState>`, where `ChatState` is the
message list plus an `isSending` flag. `build()` loads the thread from
`GET /api/chat`, so a conversation survives a reload.

`send` appends the user's message, awaits the reply, then appends it. When the
backend reports `boardChanged: true` it calls
`ref.invalidate(boardViewModelProvider)` and the board refetches on its own -
that is the whole mechanism behind the board updating after an AI change.

A failed send **removes** the user's message rather than leaving it in the
thread, puts a `ChatRole.error` entry in its place, and rethrows. The sidebar
catches that and restores the text to the composer. The message never reached
the backend, so leaving it sitting in the thread would misrepresent what
happened.

`chatOpenProvider` is a `Notifier<bool>` holding whether the panel is open.
Riverpod 3 removed `StateProvider`, so a plain `Notifier` with `toggle` and
`close` takes its place.

Enter sends and Shift+Enter inserts a newline. A multiline `TextField` never
fires `onSubmitted`, so the key is caught by a `Focus` wrapper around the field.

### Layout

`BoardScreen` uses a `LayoutBuilder`. At 900 logical pixels and wider the
sidebar sits in a `Row` and the board shrinks beside it. Below that there is not
enough room for both, so the panel is drawn over the board in a `Stack` instead
of squeezing it.

The top bar drops the "Board" and "Projects" labels and the username below 720
pixels. Without that it overflows once the Assistant button is present - a
widget test at 700 pixels catches it.

## Drag and drop

Uses the Flutter `Draggable` / `DragTarget` pair, not a package.

- `CardWidget` is a `Draggable<DraggedCard>` carrying `{cardId, fromColumnId, fromIndex}`.
  It uses `pointerDragAnchorStrategy` so the feedback follows the cursor.
- `ColumnWidget._buildCardList` is the `DragTarget`. On `onMove` and
  `onAcceptWithDetails` it calls `_calculateInsertIndex(globalOffset, column)`.
- `_calculateInsertIndex` measures each card's `RenderBox` through a per-card
  `GlobalKey` (`_cardKeys`) and returns the index of the first card whose
  vertical midpoint is below the pointer, else the end of the list.
- `_cardKeys` is pruned in `didUpdateWidget` when cards disappear.
- `_InsertIndicator` is the blue placeholder drawn at the hover index.

## Columns

Fixed at 5, created by the backend seed, with uuid ids that arrive from the API.
Do not hardcode column ids. Titles are editable in place (tap the header,
`onSubmitted` or `onTapOutside` commits; empty input reverts, and an unchanged
title makes no request). Columns cannot be added or removed - that is
intentional for the MVP.

## Theme

`AppColors` holds the project palette; do not hardcode hex values in widgets,
add them here. Note that `board_screen.dart` and `column_widget.dart` currently
contain some one-off neutral greys inline (`0xFFE5E8EE`, `0xFFEDF1F5`,
`0xFF6D7482`, `0xFFE7EAF0`) that are not in `AppColors`.

- Accent Yellow `#ECAD0A` - column top border, card left border
- Blue Primary `#209DD7` - drag affordances, text buttons, seed color
- Purple Secondary `#753991` - elevated buttons
- Dark Navy `#032147` - headings, `titleMedium`
- Gray Text `#888888` - `bodyMedium`, secondary labels

## Cards

Each card shows a pencil (edit) and a cross (delete) affordance. Edit opens
`showEditCardDialog` prefilled with the card's current title and details; both
dialogs share `_CardDialog`, which owns its controllers and disposes them.
Neither affordance is rendered on the drag feedback, since `_CardContent` only
draws them when the callbacks are non-null.

## Tests

`flutter test`, currently 58 tests.

`test/support/` holds the shared harness:

- `test_app.dart` - `FakeAuthRepository`, `useWideSurface`, `pumpApp`,
  `pumpSignedInApp`. Every test that pumps `KanbanApp` must override both
  `authRepositoryProvider` and `boardRepositoryProvider`, because the app makes
  a session request and a board request on start up. Pass `settle: false` to
  inspect a transient state; `pumpAndSettle` runs straight past a spinner, and
  hangs forever against a deliberately held load.
- `fake_board_repository.dart` - records the calls the viewmodel makes, and can
  be told to fail the next mutation (`failNextWith`), fail the load
  (`loadError`), or hold the load open (`holdLoad`).
- `fake_chat_repository.dart` - the same idea for chat, plus `boardChanged` and
  `holdSend` for the pending state.
- `board_fixture.dart` - the seeded board as test data. This is where the old
  `lib/data/dummy_data.dart` went; the app itself no longer ships dummy data.

Files:

- `test/widget_test.dart` - the board renders with its columns and cards
- `test/data/board_repository_test.dart` - every endpoint against a `MockClient`,
  asserting method, path, and body, plus error mapping and base-URI resolution
- `test/viewmodels/board_view_model_test.dart` - load, each mutation, the
  same-column decrement, and the revert path for a failed move, rename, delete,
  and add
- `test/views/board_screen_test.dart` - renders from the repository rather than
  dummy data, the loading spinner, the error state and its retry, and a failed
  mutation reverting with a SnackBar
- `test/views/login_screen_test.dart` - which screen each session state shows,
  rejected credentials, a successful login, empty-field validation, logout, and
  the username in the top bar
- `test/viewmodels/chat_view_model_test.dart` - thread loading, send, the error
  path, and that `boardChanged` does and does not trigger a board refetch
- `test/widgets/chat_sidebar_test.dart` - opening and closing, the stored
  thread, sending, the pending indicator, a failed send restoring the text, the
  board refreshing after an AI change, and both layouts
- `test/widgets/board_interaction_test.dart` - edit dialog prefill, a completed
  edit, empty-title validation, and a drag between columns driven by a manual
  multi-step gesture. These need a wide viewport, so each test calls
  `useWideSurface` before pumping; at the default 800x600 surface the second
  column is off screen and the drag test cannot reach it.

## Known gaps

- The board title and column set are fixed by the backend seed; there is no UI
  for adding or removing columns, which is intentional for the MVP.

## Testing against a browser

Widget tests cover the composer, but the in-app browser pane cannot focus
Flutter web's hidden text input, so sending a chat message cannot be driven by
hand there. Opening the sidebar, the thread loading from `GET /api/chat`, and
the layout are all verifiable in the browser; typing is not. Drive the backend
directly with `curl` when you need to exercise a chat turn end to end.
