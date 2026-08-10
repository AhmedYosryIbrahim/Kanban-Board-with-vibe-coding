# Frontend (Flutter web)

Flutter web app for the Kanban board. Package name `kanban_frontend`. All state
is still in memory, seeded from dummy data, with no network calls and no auth -
persistence arrives in Part 7.

In Docker the release bundle is built by stage 1 of the root `Dockerfile` and
served by the backend at `/`. Nothing here talks to the backend yet.

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

MVVM with Riverpod. One `Notifier` owns the whole board; widgets read it and call
methods on it. There is no repository or service layer yet.

```
lib/
  main.dart                       ProviderScope + MaterialApp, routes on auth state
  data/
    auth_repository.dart          AuthRepository, AuthException, provider
  viewmodels/
    auth_view_model.dart          AuthViewModel + authViewModelProvider
  views/
    login_screen.dart             LoginScreen
  models/
    board.dart                    Board { List<BoardColumn> columns }
    board_column.dart             BoardColumn { id, title, List<CardItem> cards }
    card_item.dart                CardItem { id, title, details }
  viewmodels/
    board_view_model.dart         BoardViewModel + boardViewModelProvider
  views/
    board_screen.dart             BoardScreen, _WebTopBar
  widgets/
    column_widget.dart            ColumnWidget (title edit, drop target, insert indicator)
    card_widget.dart              CardWidget, _CardContent, DraggedCard payload
    card_dialog.dart              showAddCardDialog, showEditCardDialog, shared _CardDialog
  data/
    dummy_data.dart               buildDummyBoard() - 5 columns, 6 cards
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

`BoardViewModel extends Notifier<Board>`, exposed as `boardViewModelProvider`.
`build()` returns `buildDummyBoard()`.

Methods:

- `renameColumn(columnId, newTitle)`
- `addCard(columnId, title, details)` - generates a v4 uuid
- `updateCard(columnId, cardId, title, details)` - no-op on an unknown id
- `deleteCard(columnId, cardId)`
- `moveCard({cardId, fromColumnId, toColumnId, targetIndex})` - handles both
  cross-column moves and same-column reordering. For same-column moves the
  target index is decremented when moving downward, because the card is removed
  before reinsertion.

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

Fixed at 5, defined in `dummy_data.dart` with stable ids: `todo`, `in-progress`,
`review`, `blocked`, `done`. Titles are editable in place (tap the header,
`onSubmitted` or `onTapOutside` commits; empty input reverts). Columns cannot be
added or removed - that is intentional for the MVP.

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

`flutter test`, currently 21 tests.

`test/support/test_app.dart` holds the shared helpers: `FakeAuthRepository`,
`useWideSurface`, `pumpApp`, and `pumpSignedInApp`. Every test that pumps
`KanbanApp` must override `authRepositoryProvider`, because the app now makes a
real session request on start up.

- `test/widget_test.dart` - renders `KanbanApp`, asserts the 5 column titles and
  one card title appear
- `test/viewmodels/board_view_model_test.dart` - covers the seed board and every
  `BoardViewModel` method including same-column reorder, indexed insert, and
  `updateCard` on both a real and an unknown id. Uses a fresh
  `ProviderContainer` per test with `addTearDown(container.dispose)`.
- `test/widgets/board_interaction_test.dart` - edit dialog prefill, a completed
  edit, empty-title validation, and a drag between columns driven by a manual
  multi-step gesture. These need a wide viewport, so each test calls
  `useWideSurface` before pumping; at the default 800x600 surface the second
  column is off screen and the drag test cannot reach it.
- `test/views/login_screen_test.dart` - which screen each session state shows,
  rejected credentials, a successful login, empty-field validation, logout, and
  the username in the top bar.

## Known gaps

These are expected to be closed by later parts of `docs/PLAN.md`:

- The board itself is still in memory. `BoardViewModel` seeds from
  `dummy_data.dart` and nothing about the board is persisted, so board changes
  are lost on reload even though the session is not.
- The board title "Product Roadmap" and subtitle are hardcoded in
  `board_screen.dart`.
- No AI chat sidebar.

## Conventions

- Match the existing style: `const` constructors, trailing commas, doc comment
  on each public class explaining its role.
- Keep business logic in `BoardViewModel`, not in widgets. Widgets call
  `ref.read(boardViewModelProvider.notifier)`.
- Add a viewmodel unit test for every new viewmodel method.
- No emojis anywhere.
