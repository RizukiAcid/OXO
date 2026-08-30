import 'dart:async';
import 'package:flutter/material.dart';
import 'game_logic.dart';
import 'game_mode.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final BotDifficulty difficulty;
  final String playerSymbol;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.localMultiplayer,
    this.difficulty = BotDifficulty.medium,
    this.playerSymbol = 'X',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late GameLogic _game;
  bool _isBotThinking = false;
  Timer? _botTimer;

  String get _botSymbol => widget.playerSymbol == 'X' ? 'O' : 'X';

  // Animation controllers
  late AnimationController _winnerBannerController;
  late Animation<double> _winnerBannerAnimation;

  late AnimationController _boardShakeController;
  late Animation<Offset> _boardShakeAnimation;

  // Per-cell scale animations
  final List<AnimationController> _cellControllers = [];
  final List<Animation<double>> _cellScales = [];

  static const _bgColor = Color(0xFF12121F);
  static const _surfaceColor = Color(0xFF1E1E30);
  static const _accentX = Color(0xFF6C63FF);   // purple for X
  static const _accentO = Color(0xFFFF6584);   // rose for O
  static const _lineColor = Color(0xFF2E2E45);

  @override
  void initState() {
    super.initState();
    _game = GameLogic();

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

    // Cell animations
    for (int i = 0; i < 9; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
      _cellControllers.add(controller);
      _cellScales.add(scale);
    }

    // If VS Bot and Bot moves first ('X'), schedule bot move
    if (widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol) {
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
    for (final c in _cellControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCellTap(int index) {
    if (_isBotThinking) return;
    if (!_game.canPlay(index)) return;
    if (widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol) return;

    _executeMove(index);

    // If game mode is VS Bot and game is not over, trigger Bot response
    if (widget.gameMode == GameMode.vsBot &&
        !_game.isGameOver &&
        _game.currentPlayer == _botSymbol) {
      _scheduleBotMove();
    }
  }

  void _executeMove(int index) {
    setState(() {
      _game.play(index);
    });

    // Animate the cell
    _cellControllers[index].forward(from: 0);

    if (_game.winner != null) {
      _winnerBannerController.forward(from: 0);
    } else if (_game.isDraw) {
      _boardShakeController.forward(from: 0);
    }
  }

  void _scheduleBotMove() {
    setState(() {
      _isBotThinking = true;
    });

    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _game.isGameOver) {
        setState(() {
          _isBotThinking = false;
        });
        return;
      }

      final botMove = _game.getBotMove(widget.difficulty, _botSymbol);
      if (botMove != -1 && _game.canPlay(botMove)) {
        _executeMove(botMove);
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
    setState(() {
      _game.reset();
      _isBotThinking = false;
    });
    _winnerBannerController.reset();
    _boardShakeController.reset();
    for (final c in _cellControllers) {
      c.reset();
    }

    if (widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol) {
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
    final boardSize = (size.width < size.height ? size.width : size.height) * 0.88;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTopAppBar(),
            const SizedBox(height: 20),
            _buildScoreBoard(),
            const SizedBox(height: 24),
            _buildTurnIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SlideTransition(
                  position: _boardShakeAnimation,
                  child: _buildBoard(boardSize),
                ),
              ),
            ),
            _buildStatusArea(),
            const SizedBox(height: 20),
            _buildResetButton(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back to menu button
          IconButton(
            onPressed: () => Navigator.pop(context),
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
              Text('O', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _accentO)),
              Text('X', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _accentX)),
              Text('O', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _accentO)),
            ],
          ),

          // Game mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.gameMode == GameMode.vsBot
                  ? _accentO.withAlpha(25)
                  : _accentX.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.gameMode == GameMode.vsBot ? _accentO : _accentX,
                width: 1,
              ),
            ),
            child: Text(
              widget.gameMode == GameMode.vsBot
                  ? 'VS BOT (${widget.difficulty.label.toUpperCase()} • ${widget.playerSymbol})'
                  : 'LOCAL 2P',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.gameMode == GameMode.vsBot ? _accentO : _accentX,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    final labelX = widget.gameMode == GameMode.vsBot
        ? (widget.playerSymbol == 'X' ? 'YOU (X)' : 'BOT (X)')
        : 'PLAYER X';
    final labelO = widget.gameMode == GameMode.vsBot
        ? (widget.playerSymbol == 'O' ? 'YOU (O)' : 'BOT (O)')
        : 'PLAYER O';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lineColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildScoreItem(labelX, _game.scoreX, _accentX),
          _buildDivider(),
          _buildScoreItem('DRAW', _game.scoreDraw, Colors.white54),
          _buildDivider(),
          _buildScoreItem(labelO, _game.scoreO, _accentO),
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
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 26,
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
      height: 38,
      color: _lineColor,
    );
  }

  Widget _buildTurnIndicator() {
    if (_game.isGameOver) return const SizedBox(height: 24);

    final isBotTurn = widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol;
    final color = _playerColor(_game.currentPlayer);
    final text = isBotTurn
        ? "Bot is thinking..."
        : widget.gameMode == GameMode.vsBot
            ? "Your turn (${widget.playerSymbol})"
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

  Widget _buildBoard(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                final index = row * 3 + col;
                return Expanded(
                  child: _buildCell(index, row, col),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell(int index, int row, int col) {
    final value = _game.board[index];
    final isWinCell = _game.winningCells.contains(index);
    final color = _playerColor(value);

    // Border logic for grid lines
    final showRight = col < 2;
    final showBottom = row < 2;

    return GestureDetector(
      onTap: () => _onCellTap(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: showRight
                ? BorderSide(color: _lineColor, width: 2)
                : BorderSide.none,
            bottom: showBottom
                ? BorderSide(color: _lineColor, width: 2)
                : BorderSide.none,
          ),
          color: isWinCell
              ? color.withAlpha(25)
              : Colors.transparent,
        ),
        child: Center(
          child: value != null
              ? ScaleTransition(
                  scale: _cellScales[index],
                  child: _buildSymbol(value, isWinCell),
                )
              : _game.isGameOver
                  ? const SizedBox.shrink()
                  : _buildEmptyHint(),
        ),
      ),
    );
  }

  Widget _buildSymbol(String value, bool isWinCell) {
    final color = _playerColor(value);
    return Text(
      value,
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: isWinCell ? color : color.withAlpha(230),
        height: 1,
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _lineColor,
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_game.winner != null) {
      final color = _playerColor(_game.winner);
      final winText = widget.gameMode == GameMode.vsBot
          ? (_game.winner == widget.playerSymbol ? '🎉 You Won!' : '🤖 Bot Won!')
          : '🎉 Player ${_game.winner} wins!';

      return ScaleTransition(
        scale: _winnerBannerAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(100), width: 1.5),
          ),
          child: Text(
            winText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    } else if (_game.isDraw) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: const Text(
          "It's a draw!",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      );
    }
    return const SizedBox(height: 50);
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _resetGame,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 14),
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'New Game',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
