# Kanban Board

A single-board Kanban project management app built with Flutter web.

## Features

- One board with 5 fixed, renamable columns
- Cards with a title and details
- Drag and drop cards between columns
- Add and delete cards
- Populated with dummy data on startup, no persistence

## Architecture

- MVVM with Riverpod (`Notifier`/`NotifierProvider`) for state management
- `lib/models` - domain models (Board, BoardColumn, CardItem)
- `lib/viewmodels` - state and business logic
- `lib/views` and `lib/widgets` - UI

## Running

```
flutter run -d chrome
```

## Testing

```
flutter test
```
