import 'dart:math';
import 'game_mode.dart';

class GameLogic {
  List<String?> board = List.filled(9, null);
  String currentPlayer = 'X';
  String? winner;
  List<int> winningCells = [];
  bool isDraw = false;

  int scoreX = 0;
  int scoreO = 0;
  int scoreDraw = 0;

  static const _winPatterns = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  bool get isGameOver => winner != null || isDraw;

  bool canPlay(int index) {
    return !isGameOver && board[index] == null;
  }

  void play(int index) {
    if (!canPlay(index)) return;

    board[index] = currentPlayer;

    // Check for winner
    for (final pattern in _winPatterns) {
      final a = pattern[0], b = pattern[1], c = pattern[2];
      if (board[a] != null && board[a] == board[b] && board[b] == board[c]) {
        winner = board[a];
        winningCells = [a, b, c];
        _updateScore();
        return;
      }
    }

    // Check for draw
    if (board.every((cell) => cell != null)) {
      isDraw = true;
      scoreDraw++;
      return;
    }

    // Switch player
    currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
  }

  void _updateScore() {
    if (winner == 'X') {
      scoreX++;
    } else if (winner == 'O') {
      scoreO++;
    }
  }

  void reset() {
    board = List.filled(9, null);
    currentPlayer = 'X';
    winner = null;
    winningCells = [];
    isDraw = false;
  }

  /// Calculates the best move for the Bot based on difficulty and assigned symbol
  int getBotMove(BotDifficulty difficulty, String botSymbol) {
    List<int> availableMoves = [];
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) availableMoves.add(i);
    }

    if (availableMoves.isEmpty) return -1;

    final rand = Random();

    // Easy: 70% random move
    if (difficulty == BotDifficulty.easy && rand.nextDouble() < 0.70) {
      return availableMoves[rand.nextInt(availableMoves.length)];
    }

    // Medium: 35% random move
    if (difficulty == BotDifficulty.medium && rand.nextDouble() < 0.35) {
      return availableMoves[rand.nextInt(availableMoves.length)];
    }

    // Opening move optimization for empty board
    if (availableMoves.length == 9) {
      final openings = [0, 2, 4, 6, 8];
      return openings[rand.nextInt(openings.length)];
    }

    // Hard / Unbeatable (or smart choice for Easy/Medium remaining cases)
    final humanSymbol = botSymbol == 'X' ? 'O' : 'X';
    int bestScore = -10000;
    int bestMove = availableMoves.first;

    for (int move in availableMoves) {
      board[move] = botSymbol;
      int score = _minimax(board, 0, false, botSymbol, humanSymbol);
      board[move] = null;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  int _minimax(List<String?> tempBoard, int depth, bool isMaximizing, String botSymbol, String humanSymbol) {
    String? currentWinner = _checkWinner(tempBoard);
    if (currentWinner == botSymbol) return 10 - depth;
    if (currentWinner == humanSymbol) return depth - 10;
    if (tempBoard.every((cell) => cell != null)) return 0;

    if (isMaximizing) {
      int bestScore = -10000;
      for (int i = 0; i < 9; i++) {
        if (tempBoard[i] == null) {
          tempBoard[i] = botSymbol;
          int score = _minimax(tempBoard, depth + 1, false, botSymbol, humanSymbol);
          tempBoard[i] = null;
          bestScore = max(bestScore, score);
        }
      }
      return bestScore;
    } else {
      int bestScore = 10000;
      for (int i = 0; i < 9; i++) {
        if (tempBoard[i] == null) {
          tempBoard[i] = humanSymbol;
          int score = _minimax(tempBoard, depth + 1, true, botSymbol, humanSymbol);
          tempBoard[i] = null;
          bestScore = min(bestScore, score);
        }
      }
      return bestScore;
    }
  }

  String? _checkWinner(List<String?> b) {
    for (final pattern in _winPatterns) {
      final a = pattern[0], b1 = pattern[1], c = pattern[2];
      if (b[a] != null && b[a] == b[b1] && b[b1] == b[c]) {
        return b[a];
      }
    }
    return null;
  }
}
