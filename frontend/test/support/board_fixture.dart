import 'package:kanban_frontend/models/board.dart';
import 'package:kanban_frontend/models/board_column.dart';
import 'package:kanban_frontend/models/card_item.dart';

/// The board the backend seeds, used as test data now that the app itself no
/// longer ships dummy data.
Board buildFixtureBoard() {
  return const Board(
    id: 1,
    name: 'Product Roadmap',
    subtitle: 'Q4 delivery board',
    columns: [
      BoardColumn(
        id: 'todo',
        title: 'To Do',
        cards: [
          CardItem(
            id: 'c1',
            title: 'Design onboarding flow',
            details: 'Sketch wireframes for the new user onboarding.',
          ),
          CardItem(
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
          CardItem(
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
          CardItem(
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
          CardItem(
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
          CardItem(
            id: 'c6',
            title: 'Project kickoff meeting',
            details: 'Aligned on scope and timeline with stakeholders.',
          ),
        ],
      ),
    ],
  );
}
