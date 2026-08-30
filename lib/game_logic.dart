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
}
