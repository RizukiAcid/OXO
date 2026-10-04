import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxo/game_logic.dart';
import 'package:oxo/game_mode.dart';
import 'package:oxo/game_screen.dart';

void main() {
  group('3-Piece Relocate GameLogic Unit Tests', () {
    late GameLogic game;

    setUp(() {
      game = GameLogic(rule: BoardRule.relocate);
    });

    test('Initial Relocate state is clean', () {
      expect(game.rule, BoardRule.relocate);
      expect(game.board, List.filled(9, null));
      expect(game.currentPlayer, 'X');
      expect(game.winner, isNull);
      expect(game.isDraw, isFalse);
      expect(game.selectedPiece, isNull);
      expect(game.lastMovedFromIndex, isNull);
      expect(game.lastMovedToIndex, isNull);
      expect(game.pieceCount('X'), 0);
      expect(game.pieceCount('O'), 0);
    });

    test('Phase 1: Players place up to 3 markings on empty fields', () {
      // Moves 1-6
      game.play(0); // X (1/3)
      expect(game.board[0], 'X');
      expect(game.pieceCount('X'), 1);

      game.play(3); // O (1/3)
      expect(game.board[3], 'O');
      expect(game.pieceCount('O'), 1);

      game.play(1); // X (2/3)
      expect(game.pieceCount('X'), 2);

      game.play(4); // O (2/3)
      expect(game.pieceCount('O'), 2);

      game.play(8); // X (3/3)
      expect(game.pieceCount('X'), 3);

      game.play(6); // O (3/3)
      expect(game.pieceCount('O'), 3);

      expect(game.board.where((c) => c != null).length, 6);
      expect(game.winner, isNull);
    });

    test('Phase 2: Once capped at 3 markers, player cannot place 4th without choosing a marker', () {
      // Fill 3 pieces each
      game.play(0); // X
      game.play(3); // O
      game.play(1); // X
      game.play(4); // O
      game.play(8); // X
      game.play(6); // O

      expect(game.currentPlayer, 'X');
      expect(game.pieceCount('X'), 3);

      // Attempting to play directly into empty cell 7 without selecting a piece is rejected
      expect(game.canPlay(7), isFalse);
      game.play(7);
      expect(game.board[7], isNull, reason: 'Must choose an existing marker first');
      expect(game.currentPlayer, 'X');
    });

    test('Player can select, switch, and deselect their own existing markers', () {
      // Setup 3 pieces each
      game.play(0); // X
      game.play(3); // O
      game.play(1); // X
      game.play(4); // O
      game.play(8); // X
      game.play(6); // O

      // X turn:
      expect(game.canSelectPiece(0), isTrue);
      expect(game.canSelectPiece(1), isTrue);
      expect(game.canSelectPiece(8), isTrue);
      // Cannot select O pieces or empty cells
      expect(game.canSelectPiece(3), isFalse);
      expect(game.canSelectPiece(7), isFalse);

      // Select piece 0
      game.play(0);
      expect(game.selectedPiece, 0);
      expect(game.isSelectedPiece(0), isTrue);

      // Switch selection to piece 8
      game.play(8);
      expect(game.selectedPiece, 8);
      expect(game.isSelectedPiece(8), isTrue);
      expect(game.isSelectedPiece(0), isFalse);

      // Toggle off / deselect by tapping piece 8 again
      game.play(8);
      expect(game.selectedPiece, isNull);
      expect(game.isSelectedPiece(8), isFalse);
    });

    test('Relocating any existing marker to an empty field moves the marker correctly', () {
      // Setup:
      // X: 0, 1, 8
      // O: 3, 4, 6
      game.play(0); // X
      game.play(3); // O
      game.play(1); // X
      game.play(4); // O
      game.play(8); // X
      game.play(6); // O

      // X selects marker at 8
      game.play(8);
      expect(game.selectedPiece, 8);

      // Available empty cells are 2, 5, 7
      expect(game.canPlay(7), isTrue);
      // X moves marker from 8 to 7
      game.play(7);

      expect(game.board[8], isNull, reason: 'Old position must be empty');
      expect(game.board[7], 'X', reason: 'New position must contain X');
      expect(game.lastMovedFromIndex, 8);
      expect(game.lastMovedToIndex, 7);
      expect(game.selectedPiece, isNull);
      expect(game.pieceCount('X'), 3, reason: 'Total pieces for X remains strictly 3');

      // Turn switches to O
      expect(game.currentPlayer, 'O');

      // O selects marker at 3 and moves to vacated cell 8
      game.play(3);
      expect(game.selectedPiece, 3);
      game.play(8);

      expect(game.board[3], isNull);
      expect(game.board[8], 'O');
      expect(game.currentPlayer, 'X');
    });

    test('Winning by relocating a marker to complete 3-in-a-row', () {
      // X: 8 (irrelevant), 0, 1
      // O: 3, 4, 6
      game.play(8); // X at 8
      game.play(3); // O at 3
      game.play(0); // X at 0
      game.play(4); // O at 4
      game.play(1); // X at 1
      game.play(6); // O at 6

      expect(game.winner, isNull);

      // X moves marker 8 to empty cell 2 -> completes row [0, 1, 2]!
      game.play(8); // select 8
      game.play(2); // move to 2

      expect(game.board[8], isNull);
      expect(game.board[0], 'X');
      expect(game.board[1], 'X');
      expect(game.board[2], 'X');
      expect(game.winner, 'X');
      expect(game.winningCells, [0, 1, 2]);
      expect(game.scoreX, 1);
      expect(game.isGameOver, isTrue);
    });

    test('Bot in Relocate mode blocks immediate winning placement and relocation', () {
      // Placement phase:
      game.play(0); // Human X at 0
      game.play(4); // Bot O at 4
      game.play(1); // Human X at 1 (threatens 2)

      // Bot should block at cell 2
      final botMove = game.getBotMove(BotDifficulty.hard, 'O');
      expect(botMove, 2);
    });

    test('Bot in Relocate movement phase finds immediate winning relocation', () {
      // Setup board where Bot O can win by moving to complete [3, 4, 5]:
      // Bot O pieces at: 3, 4, 8
      // Human X pieces at: 0, 1, 7
      // Cell 5 is empty!
      game.board[0] = 'X';
      game.board[1] = 'X';
      game.board[7] = 'X';
      game.board[3] = 'O';
      game.board[4] = 'O';
      game.board[8] = 'O';

      final botMove = game.getBotRelocateMove(BotDifficulty.hard, 'O');
      expect(botMove, isNotNull);
      expect(botMove!.to, 5, reason: 'Bot must relocate to cell 5 to complete winning row [3, 4, 5]');
      expect(botMove.from, 8, reason: 'Bot relocates piece from 8 to 5');
    });

    test('switchRule switches to Relocate cleanly and resets state', () {
      game.play(0);
      game.switchRule(BoardRule.classic);
      expect(game.rule, BoardRule.classic);

      game.switchRule(BoardRule.relocate);
      expect(game.rule, BoardRule.relocate);
      expect(game.board, List.filled(9, null));
      expect(game.selectedPiece, isNull);
    });
  });

  group('3-Piece Relocate GameScreen Widget Tests', () {
    testWidgets('Mode toggle switches to 3-Piece Relocate and displays badge', (WidgetTester tester) async {
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

      expect(find.text('3-Piece Relocate'), findsOneWidget);

      // Switch to 3-Piece Relocate
      await tester.tap(find.byKey(const ValueKey('toggle_3_piece_relocate')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LOCAL 2P • RELOCATE'), findsOneWidget);
    });

    testWidgets('Turn indicator and cell interaction for 3-Piece Relocate mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(
            gameMode: GameMode.localMultiplayer,
            initialRule: BoardRule.relocate,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initial turn indicator
      expect(find.text("X's turn • Place marker (1/3)"), findsOneWidget);

      // Turn 1: X at 0
      await tester.tap(find.byKey(const ValueKey('cell_0')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text("O's turn • Place marker (1/3)"), findsOneWidget);

      // Turn 2: O at 3
      await tester.tap(find.byKey(const ValueKey('cell_3')));
      await tester.pump(const Duration(milliseconds: 100));

      // Turn 3: X at 1
      await tester.tap(find.byKey(const ValueKey('cell_1')));
      await tester.pump(const Duration(milliseconds: 100));

      // Turn 4: O at 4
      await tester.tap(find.byKey(const ValueKey('cell_4')));
      await tester.pump(const Duration(milliseconds: 100));

      // Turn 5: X at 8 (X has placed 3 markers)
      await tester.tap(find.byKey(const ValueKey('cell_8')));
      await tester.pump(const Duration(milliseconds: 100));

      // Turn 6: O at 6 (O has placed 3 markers)
      await tester.tap(find.byKey(const ValueKey('cell_6')));
      await tester.pump(const Duration(milliseconds: 100));

      // Turn 7: X has 3 markers on board. Prompt says: "Tap a marker to relocate"
      expect(find.text("X's turn • Tap a marker to relocate"), findsOneWidget);

      // X taps marker at cell 8:
      await tester.tap(find.byKey(const ValueKey('cell_8')));
      await tester.pump(const Duration(milliseconds: 100));

      // Prompt updates to: "Tap an empty cell to move"
      expect(find.text("X's turn • Tap an empty cell to move"), findsOneWidget);
      // 'MOVE' badge appears on the selected piece
      expect(find.text('MOVE'), findsOneWidget);

      // X taps empty cell 2:
      await tester.tap(find.byKey(const ValueKey('cell_2')));
      await tester.pump(const Duration(milliseconds: 300));

      // Marker 8 relocated to 2! Completing row [0, 1, 2] -> X wins!
      expect(find.text('🎉 Player X wins!'), findsOneWidget);
    });
  });
}
