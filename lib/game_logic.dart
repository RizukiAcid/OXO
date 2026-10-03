import 'dart:collection';
import 'dart:math';
import 'game_mode.dart';

class GameLogic {
  BoardRule rule;
  List<String?> board = List.filled(9, null);
  final Queue<int> queueX = Queue<int>();
  final Queue<int> queueO = Queue<int>();
  String currentPlayer = 'X';
  String? winner;
  List<int> winningCells = [];
  bool isDraw = false;
  int? lastEvictedIndex;

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

  GameLogic({this.rule = BoardRule.classic});

  bool get isGameOver => winner != null || isDraw;

  Queue<int> get activeQueue => currentPlayer == 'X' ? queueX : queueO;
  Queue<int> get opponentQueue => currentPlayer == 'X' ? queueO : queueX;
  Queue<int> queueFor(String player) => player == 'X' ? queueX : queueO;

  int? get oldestX => (rule == BoardRule.fifo && queueX.length >= 3) ? queueX.first : null;
  int? get oldestO => (rule == BoardRule.fifo && queueO.length >= 3) ? queueO.first : null;

  bool isOldestPiece(int index) {
    if (rule != BoardRule.fifo) return false;
    return index == oldestX || index == oldestO;
  }

  bool isCurrentPlayerOldest(int index) {
    if (rule != BoardRule.fifo) return false;
    final currentOldest = currentPlayer == 'X' ? oldestX : oldestO;
    return index == currentOldest;
  }

  String? getOldestPiecePlayer(int index) {
    if (rule != BoardRule.fifo) return null;
    if (index == oldestX) return 'X';
    if (index == oldestO) return 'O';
    return null;
  }

  bool canPlay(int index) {
    return !isGameOver && board[index] == null;
  }

  void play(int index) {
    if (!canPlay(index)) return;

    lastEvictedIndex = null;

    if (rule == BoardRule.fifo) {
      final q = activeQueue;
      if (q.length >= 3) {
        lastEvictedIndex = q.removeFirst();
      }
      q.add(index);
      _syncBoardFromQueues();
    } else {
      activeQueue.add(index);
      board[index] = currentPlayer;
    }

    // Check for winner (evaluated AFTER eviction and placement)
    for (final pattern in _winPatterns) {
      final a = pattern[0], b = pattern[1], c = pattern[2];
      if (board[a] != null && board[a] == board[b] && board[b] == board[c]) {
        winner = board[a];
        winningCells = [a, b, c];
        _updateScore();
        return;
      }
    }

    // Check for draw (only applicable in classic mode; in FIFO max 6 pieces exist)
    if (rule == BoardRule.classic && board.every((cell) => cell != null)) {
      isDraw = true;
      scoreDraw++;
      return;
    }

    // Switch player
    currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
  }

  void _syncBoardFromQueues() {
    board.fillRange(0, 9, null);
    for (final idx in queueX) {
      board[idx] = 'X';
    }
    for (final idx in queueO) {
      board[idx] = 'O';
    }
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
    queueX.clear();
    queueO.clear();
    currentPlayer = 'X';
    winner = null;
    winningCells = [];
    isDraw = false;
    lastEvictedIndex = null;
  }

  void switchRule(BoardRule newRule) {
    rule = newRule;
    reset();
  }

  /// Calculates the best move for the Bot based on difficulty, mode, and assigned symbol
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

    // Classic Mode logic
    if (rule == BoardRule.classic) {
      // Opening move optimization for empty board
      if (availableMoves.length == 9) {
        final openings = [0, 2, 4, 6, 8];
        return openings[rand.nextInt(openings.length)];
      }

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

    // 3-Piece FIFO Mode logic
    final humanSymbol = botSymbol == 'X' ? 'O' : 'X';
    final botQ = queueFor(botSymbol);
    final humanQ = queueFor(humanSymbol);

    // 1. Immediate winning move for Bot
    for (int move in availableMoves) {
      if (_wouldWinFifo(botQ, move)) {
        return move;
      }
    }

    // 2. Immediate winning move for Human that Bot should block
    for (int move in availableMoves) {
      if (_wouldWinFifo(humanQ, move)) {
        return move;
      }
    }

    // 3. Prefer center if available
    if (availableMoves.contains(4)) {
      return 4;
    }

    // 4. Depth-limited FIFO minimax for strategic positioning
    int bestScore = -10000;
    int bestMove = availableMoves.first;

    final simBotQ = List<int>.from(botQ);
    final simHumanQ = List<int>.from(humanQ);

    for (int move in availableMoves) {
      int? evicted = simBotQ.length >= 3 ? simBotQ.removeAt(0) : null;
      simBotQ.add(move);

      int score = _minimaxFifo(
        simBotQ,
        simHumanQ,
        0,
        false,
        botSymbol,
        humanSymbol,
        3,
      );

      simBotQ.removeLast();
      if (evicted != null) simBotQ.insert(0, evicted);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  bool _wouldWinFifo(Queue<int> q, int move) {
    final simQ = List<int>.from(q);
    if (simQ.length >= 3) {
      simQ.removeAt(0);
    }
    simQ.add(move);

    for (final pattern in _winPatterns) {
      if (simQ.contains(pattern[0]) &&
          simQ.contains(pattern[1]) &&
          simQ.contains(pattern[2])) {
        return true;
      }
    }
    return false;
  }

  int _minimaxFifo(
    List<int> simBotQ,
    List<int> simHumanQ,
    int depth,
    bool isMaximizing,
    String botSymbol,
    String humanSymbol,
    int maxDepth,
  ) {
    for (final pattern in _winPatterns) {
      if (simBotQ.contains(pattern[0]) &&
          simBotQ.contains(pattern[1]) &&
          simBotQ.contains(pattern[2])) {
        return 100 - depth;
      }
      if (simHumanQ.contains(pattern[0]) &&
          simHumanQ.contains(pattern[1]) &&
          simHumanQ.contains(pattern[2])) {
        return depth - 100;
      }
    }

    if (depth >= maxDepth) {
      return _evaluateFifo(simBotQ, simHumanQ);
    }

    List<int> moves = [];
    for (int i = 0; i < 9; i++) {
      if (!simBotQ.contains(i) && !simHumanQ.contains(i)) {
        moves.add(i);
      }
    }

    if (moves.isEmpty) return 0;

    if (isMaximizing) {
      int bestScore = -10000;
      for (int move in moves) {
        int? evicted = simBotQ.length >= 3 ? simBotQ.removeAt(0) : null;
        simBotQ.add(move);

        int score = _minimaxFifo(
          simBotQ,
          simHumanQ,
          depth + 1,
          false,
          botSymbol,
          humanSymbol,
          maxDepth,
        );

        simBotQ.removeLast();
        if (evicted != null) simBotQ.insert(0, evicted);

        bestScore = max(bestScore, score);
      }
      return bestScore;
    } else {
      int bestScore = 10000;
      for (int move in moves) {
        int? evicted = simHumanQ.length >= 3 ? simHumanQ.removeAt(0) : null;
        simHumanQ.add(move);

        int score = _minimaxFifo(
          simBotQ,
          simHumanQ,
          depth + 1,
          true,
          botSymbol,
          humanSymbol,
          maxDepth,
        );

        simHumanQ.removeLast();
        if (evicted != null) simHumanQ.insert(0, evicted);

        bestScore = min(bestScore, score);
      }
      return bestScore;
    }
  }

  int _evaluateFifo(List<int> simBotQ, List<int> simHumanQ) {
    int score = 0;
    for (final pattern in _winPatterns) {
      int botCount = 0;
      int humanCount = 0;
      for (int idx in pattern) {
        if (simBotQ.contains(idx)) botCount++;
        if (simHumanQ.contains(idx)) humanCount++;
      }
      if (botCount > 0 && humanCount == 0) {
        score += botCount == 2 ? 10 : 1;
      } else if (humanCount > 0 && botCount == 0) {
        score -= humanCount == 2 ? 10 : 1;
      }
    }
    if (simBotQ.contains(4)) score += 3;
    if (simHumanQ.contains(4)) score -= 3;
    return score;
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
