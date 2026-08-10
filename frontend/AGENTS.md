# Frontend (Flutter web)

Flutter web app for the Kanban board. Package name `kanban_frontend`. All state
is still in memory, seeded from dummy data, with no network calls and no auth -
persistence arrives in Part 7.

In Docker the release bundle is built by stage 1 of the root `Dockerfile` and
served by the backend at `/`. Nothing here talks to the backend yet.

## Toolchain

- Flutter 3.41.8 stable, Dart SDK `^3.11.5`
- Dependencies: `flutter_riverpod` ^3.3.2, `uuid` ^4.6.0, `cupertino_icons`
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
  main.dart                       ProviderScope + MaterialApp, home: BoardScreen
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

`flutter test`, currently 14 tests:

- `test/widget_test.dart` - renders `KanbanApp`, asserts the 5 column titles and
  one card title appear
- `test/viewmodels/board_view_model_test.dart` - covers the seed board and every
  `BoardViewModel` method including same-column reorder, indexed insert, and
  `updateCard` on both a real and an unknown id. Uses a fresh
  `ProviderContainer` per test with `addTearDown(container.dispose)`.
- `test/widgets/board_interaction_test.dart` - edit dialog prefill, a completed
  edit, empty-title validation, and a drag between columns driven by a manual
  multi-step gesture. These need a wide viewport, so each test calls
  `_useWideSurface` before pumping; at the default 800x600 surface the second
  column is off screen and the drag test cannot reach it.

## Known gaps

These are expected to be closed by later parts of `docs/PLAN.md`:

- No HTTP client and no `http` dependency. All data is local and lost on reload.
- No login screen, no routing - `main.dart` goes straight to `BoardScreen`.
- `_WebTopBar` "Share" and "New task" buttons have empty `onPressed` handlers.
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
