import 'dart:math';
import 'game_mode.dart';

class UltimateGameLogic {
  List<List<String?>> localBoards = List.generate(9, (_) => List.filled(9, null));
  List<String?> globalBoard = List.filled(9, null);
  List<List<int>> localWinningCells = List.generate(9, (_) => []);
  List<int> globalWinningCells = [];

  String currentPlayer = 'X';
  String? winner;
  bool isDraw = false;
  int? activeBoardIndex; // null means can play anywhere

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

  bool canPlay(int boardIndex, int cellIndex) {
    if (isGameOver) return false;
    if (activeBoardIndex != null && activeBoardIndex != boardIndex) return false;
    if (globalBoard[boardIndex] != null) return false;
    if (localBoards[boardIndex][cellIndex] != null) return false;
    return true;
  }

  void play(int boardIndex, int cellIndex) {
    if (!canPlay(boardIndex, cellIndex)) return;

    localBoards[boardIndex][cellIndex] = currentPlayer;

    // Check local win
    String? localWinner = _checkWinner(localBoards[boardIndex]);
    if (localWinner != null) {
      globalBoard[boardIndex] = localWinner;
      localWinningCells[boardIndex] = _getWinningCells(localBoards[boardIndex]);
      
      // Check global win
      String? globalWinner = _checkWinner(globalBoard);
      if (globalWinner != null) {
        winner = globalWinner;
        globalWinningCells = _getWinningCells(globalBoard);
        _updateScore();
      } else if (globalBoard.every((cell) => cell != null || _isBoardFull(localBoards[globalBoard.indexOf(cell)]))) {
        // Draw logic needs refinement for ultimate, but a simple check is if all boards are resolved or full
        if (globalBoard.every((cell) => cell != null || _isBoardFull(localBoards[globalBoard.indexOf(cell)]))) {
           isDraw = true;
           scoreDraw++;
        }
      }
    } else if (_isBoardFull(localBoards[boardIndex])) {
      // It's a local draw, so the board is locked. For visual, we might mark it as a tie, but in standard UTTT it just counts as no one's.
      // We can leave globalBoard[boardIndex] as null but it won't be playable.
    }

    // Determine next active board
    if (!isGameOver) {
      if (globalBoard[cellIndex] != null || _isBoardFull(localBoards[cellIndex])) {
        activeBoardIndex = null; // Can play anywhere
      } else {
        activeBoardIndex = cellIndex;
      }
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
    }
  }

  bool _isBoardFull(List<String?> board) {
    return board.every((cell) => cell != null);
  }

  String? _checkWinner(List<String?> board) {
    for (final pattern in _winPatterns) {
      final a = pattern[0], b = pattern[1], c = pattern[2];
      if (board[a] != null && board[a] == board[b] && board[b] == board[c]) {
        return board[a];
      }
    }
    return null;
  }

  List<int> _getWinningCells(List<String?> board) {
    for (final pattern in _winPatterns) {
      final a = pattern[0], b = pattern[1], c = pattern[2];
      if (board[a] != null && board[a] == board[b] && board[b] == board[c]) {
        return [a, b, c];
      }
    }
    return [];
  }

  void _updateScore() {
    if (winner == 'X') {
      scoreX++;
    } else if (winner == 'O') {
      scoreO++;
    }
  }

  void reset() {
    localBoards = List.generate(9, (_) => List.filled(9, null));
    globalBoard = List.filled(9, null);
    localWinningCells = List.generate(9, (_) => []);
    globalWinningCells = [];
    currentPlayer = 'X';
    winner = null;
    isDraw = false;
    activeBoardIndex = null;
  }

  // BOT LOGIC

  int getBotMove(BotDifficulty difficulty, String botSymbol) {
    List<int> availableMoves = [];
    for (int b = 0; b < 9; b++) {
      if (activeBoardIndex == null || activeBoardIndex == b) {
        if (globalBoard[b] == null) {
          for (int c = 0; c < 9; c++) {
            if (localBoards[b][c] == null) {
              availableMoves.add(b * 9 + c);
            }
          }
        }
      }
    }

    if (availableMoves.isEmpty) return -1;

    final rand = Random();

    if (difficulty == BotDifficulty.easy && rand.nextDouble() < 0.6) {
      return availableMoves[rand.nextInt(availableMoves.length)];
    }
    
    if (difficulty == BotDifficulty.medium && rand.nextDouble() < 0.3) {
      return availableMoves[rand.nextInt(availableMoves.length)];
    }

    // Depth-limited Minimax with Alpha-Beta Pruning
    int maxDepth = difficulty == BotDifficulty.hard ? 4 : 3;
    if (availableMoves.length > 30 && maxDepth > 3) {
      maxDepth = 3; // Reduce depth in early game to prevent freezing
    } else if (availableMoves.length > 50) {
      maxDepth = 2; // Very early game
    }

    int bestScore = -1000000;
    List<int> bestMoves = [];
    final humanSymbol = botSymbol == 'X' ? 'O' : 'X';

    for (int move in availableMoves) {
      int b = move ~/ 9;
      int c = move % 9;

      // Make move
      localBoards[b][c] = botSymbol;
      String? prevGlobal = globalBoard[b];
      bool boardWon = false;
      if (_checkWinner(localBoards[b]) == botSymbol) {
        globalBoard[b] = botSymbol;
        boardWon = true;
      }
      int? prevActive = activeBoardIndex;
      activeBoardIndex = (globalBoard[c] != null || _isBoardFull(localBoards[c])) ? null : c;

      int score = _minimax(maxDepth - 1, -1000000, 1000000, false, botSymbol, humanSymbol);

      // Undo move
      localBoards[b][c] = null;
      if (boardWon) globalBoard[b] = prevGlobal;
      activeBoardIndex = prevActive;

      if (score > bestScore) {
        bestScore = score;
        bestMoves = [move];
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }

    if (bestMoves.isEmpty) return availableMoves[rand.nextInt(availableMoves.length)];
    return bestMoves[rand.nextInt(bestMoves.length)];
  }

  int _minimax(int depth, int alpha, int beta, bool isMaximizing, String botSymbol, String humanSymbol) {
    String? currentWinner = _checkWinner(globalBoard);
    if (currentWinner == botSymbol) return 100000 + depth;
    if (currentWinner == humanSymbol) return -100000 - depth;
    
    if (depth == 0) {
      return _evaluateBoard(botSymbol, humanSymbol);
    }

    List<int> availableMoves = [];
    for (int b = 0; b < 9; b++) {
      if (activeBoardIndex == null || activeBoardIndex == b) {
        if (globalBoard[b] == null) {
          for (int c = 0; c < 9; c++) {
            if (localBoards[b][c] == null) {
              availableMoves.add(b * 9 + c);
            }
          }
        }
      }
    }

    if (availableMoves.isEmpty) {
      return _evaluateBoard(botSymbol, humanSymbol);
    }

    if (isMaximizing) {
      int maxEval = -1000000;
      for (int move in availableMoves) {
        int b = move ~/ 9;
        int c = move % 9;

        localBoards[b][c] = botSymbol;
        String? prevGlobal = globalBoard[b];
        bool boardWon = false;
        if (_checkWinner(localBoards[b]) == botSymbol) {
          globalBoard[b] = botSymbol;
          boardWon = true;
        }
        int? prevActive = activeBoardIndex;
        activeBoardIndex = (globalBoard[c] != null || _isBoardFull(localBoards[c])) ? null : c;

        int eval = _minimax(depth - 1, alpha, beta, false, botSymbol, humanSymbol);

        localBoards[b][c] = null;
        if (boardWon) globalBoard[b] = prevGlobal;
        activeBoardIndex = prevActive;

        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 1000000;
      for (int move in availableMoves) {
        int b = move ~/ 9;
        int c = move % 9;

        localBoards[b][c] = humanSymbol;
        String? prevGlobal = globalBoard[b];
        bool boardWon = false;
        if (_checkWinner(localBoards[b]) == humanSymbol) {
          globalBoard[b] = humanSymbol;
          boardWon = true;
        }
        int? prevActive = activeBoardIndex;
        activeBoardIndex = (globalBoard[c] != null || _isBoardFull(localBoards[c])) ? null : c;

        int eval = _minimax(depth - 1, alpha, beta, true, botSymbol, humanSymbol);

        localBoards[b][c] = null;
        if (boardWon) globalBoard[b] = prevGlobal;
        activeBoardIndex = prevActive;

        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluateBoard(String botSymbol, String humanSymbol) {
    int score = 0;
    
    // Evaluate global board
    score += _evaluateLine(globalBoard, botSymbol, humanSymbol) * 100;
    
    // Evaluate local boards
    for (int b = 0; b < 9; b++) {
      if (globalBoard[b] == botSymbol) {
        score += 50; // Bonus for winning a local board
      } else if (globalBoard[b] == humanSymbol) {
        score -= 50;
      } else {
        score += _evaluateLine(localBoards[b], botSymbol, humanSymbol);
      }
    }
    
    // Penalty for sending opponent to a free board if we don't have to
    if (activeBoardIndex == null) {
      // activeBoardIndex null for next player means they get a free choice.
      // If we are evaluating from the perspective of having just made a move,
      // and the next player (human) has a free choice, that's bad.
      // But this evaluation happens at the leaves, so the player to move could be either.
    }

    return score;
  }

  int _evaluateLine(List<String?> board, String bot, String human) {
    int score = 0;
    for (final pattern in _winPatterns) {
      int botCount = 0;
      int humanCount = 0;
      for (int i = 0; i < 3; i++) {
        if (board[pattern[i]] == bot) {
          botCount++;
        } else if (board[pattern[i]] == human) {
          humanCount++;
        }
      }
      
      if (botCount > 0 && humanCount == 0) {
        if (botCount == 1) {
          score += 1;
        } else if (botCount == 2) {
          score += 10;
        } else if (botCount == 3) {
          score += 100;
        }
      } else if (humanCount > 0 && botCount == 0) {
        if (humanCount == 1) {
          score -= 1;
        } else if (humanCount == 2) {
          score -= 10;
        } else if (humanCount == 3) {
          score -= 100;
        }
      }
    }
    return score;
  }
}
