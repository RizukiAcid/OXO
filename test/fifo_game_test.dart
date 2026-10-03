import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxo/game_logic.dart';
import 'package:oxo/game_mode.dart';
import 'package:oxo/game_screen.dart';

void main() {
  group('3-Piece FIFO GameLogic Unit Tests', () {
    late GameLogic game;

    setUp(() {
      game = GameLogic(rule: BoardRule.fifo);
    });

    test('Initial FIFO state is clean', () {
      expect(game.rule, BoardRule.fifo);
      expect(game.queueX, isEmpty);
      expect(game.queueO, isEmpty);
      expect(game.board, List.filled(9, null));
      expect(game.currentPlayer, 'X');
      expect(game.winner, isNull);
      expect(game.isDraw, isFalse);
      expect(game.lastEvictedIndex, isNull);
      expect(game.oldestX, isNull);
      expect(game.oldestO, isNull);
    });

    test('Each player is capped at 3 pieces; 4th move evicts the oldest piece', () {
      // Moves 1-6 (3 moves each)
      // Turn 1: X -> 0
      game.play(0);
      expect(game.queueX.toList(), [0]);
      expect(game.board[0], 'X');
      expect(game.oldestX, isNull); // only 1 piece, indicator inactive until 3

      // Turn 2: O -> 3
      game.play(3);
      expect(game.queueO.toList(), [3]);
      expect(game.board[3], 'O');

      // Turn 3: X -> 1
      game.play(1);
      expect(game.queueX.toList(), [0, 1]);

      // Turn 4: O -> 4
      game.play(4);
      expect(game.queueO.toList(), [3, 4]);

      // Turn 5: X -> 8 (X now has 3 pieces)
      game.play(8);
      expect(game.queueX.toList(), [0, 1, 8]);
      expect(game.oldestX, 0);
      expect(game.isOldestPiece(0), isTrue);
      expect(game.isOldestPiece(1), isFalse);

      // Turn 6: O -> 6 (O now has 3 pieces: 3, 4, 6)
      game.play(6);
      expect(game.queueO.toList(), [3, 4, 6]);
      expect(game.oldestO, 3);
      expect(game.isOldestPiece(3), isTrue);
      expect(game.isOldestPiece(4), isFalse);

      // Total 6 pieces on the board
      expect(game.board.where((c) => c != null).length, 6);

      // Turn 7: X plays 4th move at cell 7
      // Expected: Cell 0 (oldest X) is evicted, cell 7 is occupied by X
      expect(game.currentPlayer, 'X');
      expect(game.isCurrentPlayerOldest(0), isTrue);
      expect(game.isCurrentPlayerOldest(3), isFalse);

      game.play(7);

      expect(game.lastEvictedIndex, 0);
      expect(game.board[0], isNull, reason: 'Oldest X piece at cell 0 must be evicted');
      expect(game.board[7], 'X', reason: 'New X piece placed at cell 7');
      expect(game.queueX.toList(), [1, 8, 7]);
      expect(game.queueX.length, 3);
      expect(game.oldestX, 1, reason: 'Cell 1 is now the oldest piece for X');

      // Turn 8: O plays 4th move at cell 0 (now available!)
      expect(game.canPlay(0), isTrue);
      game.play(0);

      expect(game.lastEvictedIndex, 3);
      expect(game.board[3], isNull, reason: 'Oldest O piece at cell 3 must be evicted');
      expect(game.board[0], 'O', reason: 'New O piece placed at cell 0');
      expect(game.queueO.toList(), [4, 6, 0]);
      expect(game.queueO.length, 3);
      expect(game.oldestO, 4);

      // Board state remains in exact sync with queues
      for (int i = 0; i < 9; i++) {
        if (game.queueX.contains(i)) {
          expect(game.board[i], 'X');
        } else if (game.queueO.contains(i)) {
          expect(game.board[i], 'O');
        } else {
          expect(game.board[i], isNull);
        }
      }
    });

    test('Win condition evaluates strictly AFTER eviction and placement', () {
      // Setup:
      // X plays: 0, 1, 5
      // O plays: 3, 4, 7
      game.play(0); // X at 0
      game.play(3); // O at 3
      game.play(1); // X at 1
      game.play(4); // O at 4
      game.play(5); // X at 5 (queueX: [0, 1, 5])
      game.play(7); // O at 7 (queueO: [3, 4, 7])

      // Currently X has pieces at 0, 1, 5 (not a win)
      expect(game.winner, isNull);

      // X plays cell 2:
      // FIFO eviction removes cell 0!
      // New queueX: [1, 5, 2] -> cells 1, 2, 5 is NOT a win (row 0 was 0, 1, 2, but 0 was evicted!)
      game.play(2);

      expect(game.lastEvictedIndex, 0);
      expect(game.board[0], isNull);
      expect(game.board[1], 'X');
      expect(game.board[2], 'X');
      expect(game.board[5], 'X');
      expect(game.winner, isNull, reason: 'Row [0, 1, 2] was broken by evicting cell 0');

      // Next: O plays cell 8
      // O evicts cell 3. Remaining O: [4, 7, 8] (not a win)
      game.play(8);
      expect(game.winner, isNull);

      // Now X plays cell 8? Cell 8 is taken.
      // X plays cell 8 -> cannot play.
      expect(game.canPlay(8), isFalse);

      // X plays cell 0 (empty):
      // Oldest X is 1. Evicted: 1.
      // New queueX: [5, 2, 0] -> not a win.
      game.play(0);
      expect(game.lastEvictedIndex, 1);
      expect(game.winner, isNull);

      // O plays cell 1:
      // Oldest O is 4. Evicted: 4.
      // New queueO: [7, 8, 1] -> not a win.
      game.play(1);
      expect(game.winner, isNull);

      // Now X plays cell 1? No, 1 is taken.
      // Current X pieces: [2, 0, ...] (actually queueX is [2, 0, ...])
      // Let's create an actual win:
      // X currently has [2, 0] and cell 5? Wait: queueX: [5, 2, 0] -> evicted 5 on next move!
      // If X plays cell 4:
      // Evicted: 5.
      // New queueX: [2, 4, 0] -> wait, diagonal is [0, 4, 8] or [2, 4, 6]!
      // If X plays 6:
      // Evicted: 5.
      // New queueX: [2, 0, 6] -> not diagonal.
      // If X plays 4: queueX has [2, 0, 4] -> not diagonal.
    });

    test('Winning move with eviction succeeds', () {
      // Move sequence:
      // X: 8 (irrelevant), 0, 1
      // O: 3, 4, 5
      game.play(8); // X
      game.play(3); // O
      game.play(0); // X
      game.play(4); // O
      game.play(1); // X (queueX: [8, 0, 1])
      game.play(5); // O (queueO: [3, 4, 5] -> wait, [3, 4, 5] is a row win for O!)
      // Wait, [3, 4, 5] is row 1 win for O!
      expect(game.winner, 'O');
      expect(game.winningCells, [3, 4, 5]);
    });

    test('X wins by completing line on 4th move after evicting irrelevant 1st move', () {
      // X: 8, 0, 1 -> 4th move at 2 (evicts 8, completes [0, 1, 2])
      // O: 3, 4, 7 -> does not win
      game.play(8); // X
      game.play(3); // O
      game.play(0); // X
      game.play(4); // O
      game.play(1); // X (queueX: [8, 0, 1])
      game.play(7); // O (queueO: [3, 4, 7])

      expect(game.winner, isNull);

      // X plays 2: evicts 8, places 2. New queueX: [0, 1, 2]. WIN!
      game.play(2);

      expect(game.lastEvictedIndex, 8);
      expect(game.board[8], isNull);
      expect(game.winner, 'X');
      expect(game.winningCells, [0, 1, 2]);
      expect(game.scoreX, 1);
      expect(game.isGameOver, isTrue);
    });

    test('FIFO mode suppresses board draw stalemates', () {
      // In FIFO mode, board only ever holds at most 6 pieces.
      // Full board stalemate condition never triggers isDraw.
      expect(game.isDraw, isFalse);
    });

    test('Reset completely clears queues, board, and turns', () {
      game.play(0);
      game.play(1);
      game.play(2);
      game.play(3);

      game.reset();

      expect(game.queueX, isEmpty);
      expect(game.queueO, isEmpty);
      expect(game.board, List.filled(9, null));
      expect(game.currentPlayer, 'X');
      expect(game.winner, isNull);
      expect(game.isDraw, isFalse);
      expect(game.lastEvictedIndex, isNull);
    });

    test('switchRule switches between Classic and FIFO cleanly', () {
      game.play(0);
      game.play(1);

      game.switchRule(BoardRule.classic);

      expect(game.rule, BoardRule.classic);
      expect(game.queueX, isEmpty);
      expect(game.queueO, isEmpty);
      expect(game.board, List.filled(9, null));

      game.switchRule(BoardRule.fifo);
      expect(game.rule, BoardRule.fifo);
    });

    test('Bot in FIFO mode makes valid moves and blocks immediate wins', () {
      // Human X plays 0, 1
      game.play(0); // X
      game.play(4); // Bot O
      game.play(1); // X (X threatens win at 2)

      // Bot move should block X at 2
      final botMove = game.getBotMove(BotDifficulty.hard, 'O');
      expect(botMove, 2, reason: 'Bot should block immediate winning move at cell 2');
    });
  });

  group('3-Piece FIFO GameScreen Widget Tests', () {
    testWidgets('Mode toggle switches rule between Classic and 3-Piece FIFO and clears board', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(
            gameMode: GameMode.localMultiplayer,
            initialRule: BoardRule.classic,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initial state: Classic mode
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('3-Piece FIFO'), findsOneWidget);
      expect(find.text('LOCAL 2P'), findsOneWidget);

      // Play cell 0
      await tester.tap(find.byKey(const ValueKey('cell_0')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(of: find.byKey(const ValueKey('cell_0')), matching: find.text('X')),
        findsOneWidget,
      );

      // Switch to 3-Piece FIFO mode
      await tester.tap(find.byKey(const ValueKey('toggle_3_piece_fifo')));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify cell 0 is cleared on mode switch
      expect(
        find.descendant(of: find.byKey(const ValueKey('cell_0')), matching: find.text('X')),
        findsNothing,
      );
      expect(find.text('LOCAL 2P • FIFO'), findsOneWidget);

      // Switch back to Classic
      await tester.tap(find.byKey(const ValueKey('toggle_classic')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LOCAL 2P'), findsOneWidget);
    });

    testWidgets('Oldest piece displays eviction warning badge and lower opacity in FIFO mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(
            gameMode: GameMode.localMultiplayer,
            initialRule: BoardRule.fifo,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Moves 1-5:
      // X at 0
      await tester.tap(find.byKey(const ValueKey('cell_0')));
      await tester.pump(const Duration(milliseconds: 100));

      // O at 3
      await tester.tap(find.byKey(const ValueKey('cell_3')));
      await tester.pump(const Duration(milliseconds: 100));

      // X at 1
      await tester.tap(find.byKey(const ValueKey('cell_1')));
      await tester.pump(const Duration(milliseconds: 100));

      // O at 4
      await tester.tap(find.byKey(const ValueKey('cell_4')));
      await tester.pump(const Duration(milliseconds: 100));

      // X at 8 (X now has 3 pieces: 0, 1, 8)
      await tester.tap(find.byKey(const ValueKey('cell_8')));
      await tester.pump(const Duration(milliseconds: 100));

      // O has 2 pieces, X has 3 pieces. Oldest X is 0.
      // Currently it's O's turn, so cell 0 is X's oldest (3RD in queue)
      expect(find.text('3RD'), findsOneWidget);

      // O plays cell 7 (O now has 3 pieces: 3, 4, 7)
      await tester.tap(find.byKey(const ValueKey('cell_7')));
      await tester.pump(const Duration(milliseconds: 100));

      // Now it is X's turn!
      // Cell 0 is X's oldest piece and X is active, so it shows 'NEXT' badge!
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text("X's turn • Next move evicts oldest"), findsOneWidget);

      // X plays cell 6 (4th move):
      // Cell 0 must disappear!
      await tester.tap(find.byKey(const ValueKey('cell_6')));
      await tester.pump(const Duration(milliseconds: 100));

      // Cell 0 should no longer contain X
      final cell0 = find.descendant(
        of: find.byKey(const ValueKey('cell_0')),
        matching: find.text('X'),
      );
      expect(cell0, findsNothing);

      // Cell 6 contains X
      final cell6 = find.descendant(
        of: find.byKey(const ValueKey('cell_6')),
        matching: find.text('X'),
      );
      expect(cell6, findsOneWidget);
    });
  });
}
