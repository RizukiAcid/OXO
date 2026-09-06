import 'dart:async';
import 'package:flutter/material.dart';
import 'ultimate_game_logic.dart';
import 'game_mode.dart';

class UltimateGameScreen extends StatefulWidget {
  final GameMode gameMode;
  final BotDifficulty difficulty;
  final String playerSymbol;

  const UltimateGameScreen({
    super.key,
    this.gameMode = GameMode.ultimateLocalMultiplayer,
    this.difficulty = BotDifficulty.medium,
    this.playerSymbol = 'X',
  });

  @override
  State<UltimateGameScreen> createState() => _UltimateGameScreenState();
}

class _UltimateGameScreenState extends State<UltimateGameScreen>
    with TickerProviderStateMixin {
  late UltimateGameLogic _game;
  bool _isBotThinking = false;
  Timer? _botTimer;

  late String _playerSymbol;
  String get _botSymbol => _playerSymbol == 'X' ? 'O' : 'X';
  int _humanScore = 0;
  int _botScore = 0;

  // Animation controllers
  late AnimationController _winnerBannerController;
  late Animation<double> _winnerBannerAnimation;

  late AnimationController _boardShakeController;
  late Animation<Offset> _boardShakeAnimation;

  // We will just use basic state rebuilding for cells in UTTT due to 81 cells
  // Adding 81 animation controllers might be overkill, but we can do a simple fade/scale
  // For simplicity and performance, we'll just use AnimatedContainer and standard Flutter animations.

  static const _bgColor = Color(0xFF12121F);
  static const _surfaceColor = Color(0xFF1E1E30);
  static const _accentX = Color(0xFF6C63FF);   // purple for X
  static const _accentO = Color(0xFFFF6584);   // rose for O
  static const _lineColor = Color(0xFF2E2E45);
  static const _activeBoardColor = Color(0xFF4CAF50); // Green for active board

  @override
  void initState() {
    super.initState();
    _game = UltimateGameLogic();
    _playerSymbol = widget.playerSymbol;

    // Winner banner animation
    _winnerBannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _winnerBannerAnimation = CurvedAnimation(
      parent: _winnerBannerController,
      curve: Curves.elasticOut,
    );

    // Board shake animation for draw
    _boardShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _boardShakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0.02, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.02, 0), end: const Offset(-0.02, 0)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.02, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _boardShakeController,
      curve: Curves.easeInOut,
    ));

    if (widget.gameMode == GameMode.ultimateVsBot && _game.currentPlayer == _botSymbol) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleBotMove();
      });
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _winnerBannerController.dispose();
    _boardShakeController.dispose();
    super.dispose();
  }

  void _onCellTap(int boardIndex, int cellIndex) {
    if (_isBotThinking) return;
    if (!_game.canPlay(boardIndex, cellIndex)) return;
    if (widget.gameMode == GameMode.ultimateVsBot && _game.currentPlayer == _botSymbol) return;

    _executeMove(boardIndex, cellIndex);

    if (widget.gameMode == GameMode.ultimateVsBot &&
        !_game.isGameOver &&
        _game.currentPlayer == _botSymbol) {
      _scheduleBotMove();
    }
  }

  void _executeMove(int boardIndex, int cellIndex) {
    final wasGameOver = _game.isGameOver;
    setState(() {
      _game.play(boardIndex, cellIndex);
    });

    if (!wasGameOver && _game.winner != null) {
      if (widget.gameMode == GameMode.ultimateVsBot) {
        if (_game.winner == _playerSymbol) {
          _humanScore++;
        } else {
          _botScore++;
        }
      }
      _winnerBannerController.forward(from: 0);
    } else if (!wasGameOver && _game.isDraw) {
      _boardShakeController.forward(from: 0);
    }
  }

  void _scheduleBotMove() {
    setState(() {
      _isBotThinking = true;
    });

    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _game.isGameOver) {
        setState(() {
          _isBotThinking = false;
        });
        return;
      }

      final botMove = _game.getBotMove(widget.difficulty, _botSymbol);
      if (botMove != -1) {
        int b = botMove ~/ 9;
        int c = botMove % 9;
        if (_game.canPlay(b, c)) {
          _executeMove(b, c);
        }
      }

      if (mounted) {
        setState(() {
          _isBotThinking = false;
        });
      }
    });
  }

  void _resetGame() {
    _botTimer?.cancel();
    final wasGameOver = _game.isGameOver;
    setState(() {
      if (widget.gameMode == GameMode.ultimateVsBot && wasGameOver) {
        _playerSymbol = _playerSymbol == 'X' ? 'O' : 'X';
      }
      _game.reset();
      _isBotThinking = false;
    });
    _winnerBannerController.reset();
    _boardShakeController.reset();

    if (widget.gameMode == GameMode.ultimateVsBot && _game.currentPlayer == _botSymbol) {
      _scheduleBotMove();
    }
  }

  Color _playerColor(String? player) {
    if (player == 'X') return _accentX;
    if (player == 'O') return _accentO;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boardSize = (size.width < size.height ? size.width : size.height) * 0.95;
    final nextSymbol = widget.gameMode == GameMode.ultimateVsBot && _game.isGameOver
        ? (_playerSymbol == 'X' ? 'O' : 'X')
        : _playerSymbol;

    return PopScope<String?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, widget.gameMode == GameMode.ultimateVsBot ? nextSymbol : null);
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildTopAppBar(nextSymbol),
              const SizedBox(height: 12),
              _buildScoreBoard(),
              const SizedBox(height: 12),
              _buildTurnIndicator(),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: SlideTransition(
                    position: _boardShakeAnimation,
                    child: _buildUltimateBoard(boardSize),
                  ),
                ),
              ),
              _buildStatusArea(),
              const SizedBox(height: 12),
              _buildResetButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(String nextSymbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back to menu button
          IconButton(
            onPressed: () => Navigator.pop(
              context,
              widget.gameMode == GameMode.ultimateVsBot ? nextSymbol : null,
            ),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lineColor, width: 1),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),

          // Logo / Title
          Row(
            children: [
              Text('ULTIMATE ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
              Text('O', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _accentO)),
              Text('X', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _accentX)),
              Text('O', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _accentO)),
            ],
          ),

          // Game mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.gameMode == GameMode.ultimateVsBot
                  ? _playerColor(_playerSymbol).withAlpha(25)
                  : _accentX.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.gameMode == GameMode.ultimateVsBot
                    ? _playerColor(_playerSymbol)
                    : _accentX,
                width: 1,
              ),
            ),
            child: Text(
              widget.gameMode == GameMode.ultimateVsBot
                  ? 'BOT'
                  : '2P',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.gameMode == GameMode.ultimateVsBot
                    ? _playerColor(_playerSymbol)
                    : _accentX,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    final isVsBot = widget.gameMode == GameMode.ultimateVsBot;

    final labelLeft = isVsBot ? 'YOU ($_playerSymbol)' : 'PLAYER X';
    final scoreLeft = isVsBot ? _humanScore : _game.scoreX;
    final colorLeft = isVsBot ? _playerColor(_playerSymbol) : _accentX;

    final labelRight = isVsBot ? 'BOT ($_botSymbol)' : 'PLAYER O';
    final scoreRight = isVsBot ? _botScore : _game.scoreO;
    final colorRight = isVsBot ? _playerColor(_botSymbol) : _accentO;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildScoreItem(labelLeft, scoreLeft, colorLeft),
          _buildDivider(),
          _buildScoreItem('DRAW', _game.scoreDraw, Colors.white54),
          _buildDivider(),
          _buildScoreItem(labelRight, scoreRight, colorRight),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color.withAlpha(180),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: _lineColor,
    );
  }

  Widget _buildTurnIndicator() {
    if (_game.isGameOver) return const SizedBox(height: 24);

    final isBotTurn = widget.gameMode == GameMode.ultimateVsBot && _game.currentPlayer == _botSymbol;
    final color = _playerColor(_game.currentPlayer);
    final text = isBotTurn
        ? "Bot is thinking..."
        : widget.gameMode == GameMode.ultimateVsBot
            ? "Your turn ($_playerSymbol)"
            : "${_game.currentPlayer}'s turn";

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey("${_game.currentPlayer}_$isBotTurn"),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBotTurn) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUltimateBoard(double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lineColor, width: 2),
      ),
      child: Column(
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                final boardIndex = row * 3 + col;
                return Expanded(
                  child: _buildLocalBoard(boardIndex),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocalBoard(int boardIndex) {
    bool isActive = _game.activeBoardIndex == null || _game.activeBoardIndex == boardIndex;
    bool isWon = _game.globalBoard[boardIndex] != null;
    bool isFull = _game.localBoards[boardIndex].every((cell) => cell != null);
    
    // If the game is over, no board is 'active' for playing
    if (_game.isGameOver) isActive = false;
    if (isWon || isFull) isActive = false;

    // Highlight the active board
    Color boardBorderColor = isActive ? _activeBoardColor.withAlpha(150) : _lineColor.withAlpha(100);
    double borderWidth = isActive ? 2.5 : 1.0;

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isActive ? _activeBoardColor.withAlpha(15) : Colors.transparent,
        border: Border.all(color: boardBorderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // The 3x3 local grid
          Column(
            children: List.generate(3, (localRow) {
              return Expanded(
                child: Row(
                  children: List.generate(3, (localCol) {
                    final cellIndex = localRow * 3 + localCol;
                    return Expanded(
                      child: _buildLocalCell(boardIndex, cellIndex, isActive),
                    );
                  }),
                ),
              );
            }),
          ),
          // Giant X/O Overlay if won
          if (isWon)
            Container(
              decoration: BoxDecoration(
                color: _bgColor.withAlpha(220),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _game.globalBoard[boardIndex]!,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: _playerColor(_game.globalBoard[boardIndex]),
                    shadows: [
                      Shadow(
                        color: _playerColor(_game.globalBoard[boardIndex]).withAlpha(100),
                        blurRadius: 10,
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalCell(int boardIndex, int cellIndex, bool isBoardActive) {
    final value = _game.localBoards[boardIndex][cellIndex];
    final color = _playerColor(value);
    
    bool isCellWin = false;
    if (_game.globalBoard[boardIndex] != null && _game.localWinningCells[boardIndex].contains(cellIndex)) {
      isCellWin = true;
    }

    final showRight = (cellIndex % 3) < 2;
    final showBottom = (cellIndex ~/ 3) < 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(boardIndex, cellIndex),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: showRight ? BorderSide(color: _lineColor.withAlpha(100), width: 1) : BorderSide.none,
            bottom: showBottom ? BorderSide(color: _lineColor.withAlpha(100), width: 1) : BorderSide.none,
          ),
          color: isCellWin ? color.withAlpha(30) : Colors.transparent,
        ),
        child: Center(
          child: value != null
              ? Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isCellWin ? color : color.withAlpha(200),
                  ),
                )
              : isBoardActive && !_game.isGameOver
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lineColor,
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_game.winner != null) {
      final color = _playerColor(_game.winner);
      final winText = widget.gameMode == GameMode.ultimateVsBot
          ? (_game.winner == _playerSymbol ? '🎉 You Won!' : '🤖 Bot Won!')
          : '🎉 Player ${_game.winner} wins!';

      return ScaleTransition(
        scale: _winnerBannerAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(100), width: 1.5),
          ),
          child: Text(
            winText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    } else if (_game.isDraw) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: const Text(
          "It's a draw!",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      );
    }
    return const SizedBox(height: 36);
  }

  Widget _buildResetButton() {
    final isVsBot = widget.gameMode == GameMode.ultimateVsBot;
    final String buttonText;
    if (_game.isGameOver) {
      if (isVsBot) {
        buttonText = 'Next Match (${_playerSymbol == 'X' ? 'Play 2nd' : 'Play 1st'})';
      } else {
        buttonText = 'Next Match';
      }
    } else {
      buttonText = 'Restart';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _resetGame,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentX, const Color(0xFF9B59B6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accentX.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
