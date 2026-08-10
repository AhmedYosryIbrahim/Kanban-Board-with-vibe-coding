# Kanban Board

A single-board Kanban project management app built with Flutter web.

## Features

- Sign in and sign out against the backend session
- One board with 5 fixed, renamable columns
- Cards with a title and details
- Drag and drop cards between columns
- Add, edit, and delete cards
- Board populated with dummy data on startup, no persistence yet

## Architecture

- MVVM with Riverpod (`Notifier`/`NotifierProvider`) for state management
- `lib/models` - domain models (Board, BoardColumn, CardItem)
- `lib/viewmodels` - state and business logic
- `lib/views` and `lib/widgets` - UI

## Running

Run the whole app from the repo root, which serves this bundle and the API from
one origin:

```
./scripts/start.sh
```

`flutter run -d chrome` still works for board and layout work, but serves the
app on a different port from the API, so sign in will not work there.

## Testing

```
flutter test
```
