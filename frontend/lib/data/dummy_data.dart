import '../models/board.dart';
import '../models/board_column.dart';
import '../models/card_item.dart';

/// Initial dummy data so the board opens populated for demo purposes.
Board buildDummyBoard() {
  return Board(
    columns: [
      BoardColumn(
        id: 'todo',
        title: 'To Do',
        cards: [
          const CardItem(
            id: 'c1',
            title: 'Design onboarding flow',
            details: 'Sketch wireframes for the new user onboarding.',
          ),
          const CardItem(
            id: 'c2',
            title: 'Set up CI pipeline',
            details: 'Configure automated build and test checks.',
          ),
        ],
      ),
      BoardColumn(
        id: 'in-progress',
        title: 'In Progress',
        cards: [
          const CardItem(
            id: 'c3',
            title: 'Implement drag and drop',
            details: 'Allow cards to move between columns.',
          ),
        ],
      ),
      BoardColumn(
        id: 'review',
        title: 'Review',
        cards: [
          const CardItem(
            id: 'c4',
            title: 'Code review: auth module',
            details: 'Check for security issues before merging.',
          ),
        ],
      ),
      BoardColumn(
        id: 'blocked',
        title: 'Blocked',
        cards: [
          const CardItem(
            id: 'c5',
            title: 'Waiting on API keys',
            details: 'Blocked until third-party access is granted.',
          ),
        ],
      ),
      BoardColumn(
        id: 'done',
        title: 'Done',
        cards: [
          const CardItem(
            id: 'c6',
            title: 'Project kickoff meeting',
            details: 'Aligned on scope and timeline with stakeholders.',
          ),
        ],
      ),
    ],
  );
}
