import 'dart:async';
import 'package:flutter/material.dart';
import 'game_logic.dart';
import 'game_mode.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final BotDifficulty difficulty;
  final String playerSymbol;
  final BoardRule initialRule;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.localMultiplayer,
    this.difficulty = BotDifficulty.medium,
    this.playerSymbol = 'X',
    this.initialRule = BoardRule.classic,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late GameLogic _game;
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

  // Subtle pulse animation for oldest piece warning in FIFO mode
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _game = GameLogic(rule: widget.initialRule);
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

    // Pulse animation for FIFO oldest piece alert
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 0.5,
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 0.70).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _pulseController.dispose();
    _winnerBannerController.dispose();
    _boardShakeController.dispose();
    for (final c in _cellControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCellTap(int index) {
    if (_isBotThinking) return;
    if (widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol) return;

    if (_game.rule == BoardRule.relocate && _game.pieceCount(_game.currentPlayer) >= 3) {
      if (_game.board[index] == _game.currentPlayer) {
        setState(() {
          _game.selectPiece(index);
        });
        _updatePulseState();
        return;
      }
      if (_game.selectedPiece != null && _game.board[index] == null) {
        final from = _game.selectedPiece!;
        final to = index;
        _executeRelocateMove(from, to);

        if (widget.gameMode == GameMode.vsBot &&
            !_game.isGameOver &&
            _game.currentPlayer == _botSymbol) {
          _scheduleBotMove();
        }
        return;
      }
      return;
    }

    if (!_game.canPlay(index)) return;

    _executeMove(index);

    // If game mode is VS Bot and game is not over, trigger Bot response
    if (widget.gameMode == GameMode.vsBot &&
        !_game.isGameOver &&
        _game.currentPlayer == _botSymbol) {
      _scheduleBotMove();
    }
  }

  void _executeMove(int index) {
    final wasGameOver = _game.isGameOver;
    setState(() {
      _game.play(index);
    });

    // Animate the newly placed cell
    _cellControllers[index].forward(from: 0);

    // If a piece was evicted in FIFO mode, reset its animation controller
    if (_game.lastEvictedIndex != null) {
      _cellControllers[_game.lastEvictedIndex!].reset();
    }

    _updatePulseState();

    if (!wasGameOver && _game.winner != null) {
      if (widget.gameMode == GameMode.vsBot) {
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

  void _executeRelocateMove(int from, int to) {
    final wasGameOver = _game.isGameOver;
    setState(() {
      _game.movePiece(from, to);
    });

    _cellControllers[from].reset();
    _cellControllers[to].forward(from: 0);

    _updatePulseState();

    if (!wasGameOver && _game.winner != null) {
      if (widget.gameMode == GameMode.vsBot) {
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

  void _updatePulseState() {
    final shouldPulseFifo = _game.rule == BoardRule.fifo &&
        !_game.isGameOver &&
        (_game.queueX.length >= 3 || _game.queueO.length >= 3);
    final shouldPulseRelocate = _game.rule == BoardRule.relocate &&
        !_game.isGameOver &&
        _game.selectedPiece != null;

    if (shouldPulseFifo || shouldPulseRelocate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 0.5;
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

      if (_game.rule == BoardRule.relocate && _game.pieceCount(_botSymbol) >= 3) {
        final botRelocateMove = _game.getBotRelocateMove(widget.difficulty, _botSymbol);
        if (botRelocateMove != null) {
          _executeRelocateMove(botRelocateMove.from, botRelocateMove.to);
        }
      } else {
        final botMove = _game.getBotMove(widget.difficulty, _botSymbol);
        if (botMove != -1 && _game.canPlay(botMove)) {
          _executeMove(botMove);
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
      if (widget.gameMode == GameMode.vsBot && wasGameOver) {
        _playerSymbol = _playerSymbol == 'X' ? 'O' : 'X';
      }
      _game.reset();
      _isBotThinking = false;
    });
    _winnerBannerController.reset();
    _boardShakeController.reset();
    for (final c in _cellControllers) {
      c.reset();
    }
    _updatePulseState();

    if (widget.gameMode == GameMode.vsBot && _game.currentPlayer == _botSymbol) {
      _scheduleBotMove();
    }
  }

  void _onModeToggle(BoardRule newRule) {
    if (_game.rule == newRule) return;
    _botTimer?.cancel();
    setState(() {
      _game.switchRule(newRule);
      _isBotThinking = false;
    });
    _winnerBannerController.reset();
    _boardShakeController.reset();
    for (final c in _cellControllers) {
      c.reset();
    }
    _updatePulseState();

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
    final nextSymbol = widget.gameMode == GameMode.vsBot && _game.isGameOver
        ? (_playerSymbol == 'X' ? 'O' : 'X')
        : _playerSymbol;

    return PopScope<String?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, widget.gameMode == GameMode.vsBot ? nextSymbol : null);
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              _buildTopAppBar(nextSymbol),
              const SizedBox(height: 14),
              _buildModeToggle(),
              const SizedBox(height: 14),
              _buildScoreBoard(),
              const SizedBox(height: 16),
              _buildTurnIndicator(),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SlideTransition(
                    position: _boardShakeAnimation,
                    child: _buildBoard(boardSize),
                  ),
                ),
              ),
              _buildStatusArea(),
              const SizedBox(height: 16),
              _buildResetButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(String nextSymbol) {
    final String ruleTag;
    switch (_game.rule) {
      case BoardRule.classic:
        ruleTag = '';
        break;
      case BoardRule.fifo:
        ruleTag = ' • FIFO';
        break;
      case BoardRule.relocate:
        ruleTag = ' • RELOCATE';
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back to menu button
          IconButton(
            onPressed: () => Navigator.pop(
              context,
              widget.gameMode == GameMode.vsBot ? nextSymbol : null,
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
                  ? _playerColor(_playerSymbol).withAlpha(25)
                  : _accentX.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.gameMode == GameMode.vsBot
                    ? _playerColor(_playerSymbol)
                    : _accentX,
                width: 1,
              ),
            ),
            child: Text(
              widget.gameMode == GameMode.vsBot
                  ? 'VS BOT (${widget.difficulty.label.toUpperCase()} • $_playerSymbol$ruleTag)'
                  : 'LOCAL 2P$ruleTag',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.gameMode == GameMode.vsBot
                    ? _playerColor(_playerSymbol)
                    : _accentX,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              label: 'Classic',
              icon: Icons.grid_3x3_rounded,
              isSelected: _game.rule == BoardRule.classic,
              onTap: () => _onModeToggle(BoardRule.classic),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildToggleOption(
              label: '3-Piece FIFO',
              icon: Icons.all_inclusive_rounded,
              isSelected: _game.rule == BoardRule.fifo,
              onTap: () => _onModeToggle(BoardRule.fifo),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildToggleOption(
              label: '3-Piece Relocate',
              icon: Icons.open_with_rounded,
              isSelected: _game.rule == BoardRule.relocate,
              onTap: () => _onModeToggle(BoardRule.relocate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final keySuffix = label.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    return GestureDetector(
      key: ValueKey('toggle_$keySuffix'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? _accentX.withAlpha(45) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accentX : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accentX.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white60,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    final isVsBot = widget.gameMode == GameMode.vsBot;

    final labelLeft = isVsBot ? 'YOU ($_playerSymbol)' : 'PLAYER X';
    final scoreLeft = isVsBot ? _humanScore : _game.scoreX;
    final colorLeft = isVsBot ? _playerColor(_playerSymbol) : _accentX;

    final labelRight = isVsBot ? 'BOT ($_botSymbol)' : 'PLAYER O';
    final scoreRight = isVsBot ? _botScore : _game.scoreO;
    final colorRight = isVsBot ? _playerColor(_botSymbol) : _accentO;

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
    final has3Pieces = _game.rule == BoardRule.fifo && _game.activeQueue.length >= 3;
    final isRelocate = _game.rule == BoardRule.relocate;
    final pieceCount = _game.pieceCount(_game.currentPlayer);

    final String text;
    if (isBotTurn) {
      if (isRelocate && pieceCount >= 3) {
        text = "Bot is thinking (relocating marker)...";
      } else if (has3Pieces) {
        text = "Bot is thinking (evicting oldest)...";
      } else {
        text = "Bot is thinking...";
      }
    } else if (isRelocate) {
      final pLabel = widget.gameMode == GameMode.vsBot
          ? "Your turn ($_playerSymbol)"
          : "${_game.currentPlayer}'s turn";
      if (pieceCount < 3) {
        text = "$pLabel • Place marker (${pieceCount + 1}/3)";
      } else if (_game.selectedPiece == null) {
        text = "$pLabel • Tap a marker to relocate";
      } else {
        text = "$pLabel • Tap an empty cell to move";
      }
    } else if (widget.gameMode == GameMode.vsBot) {
      text = has3Pieces
          ? "Your turn ($_playerSymbol) • Next move evicts oldest"
          : "Your turn ($_playerSymbol)";
    } else {
      text = has3Pieces
          ? "${_game.currentPlayer}'s turn • Next move evicts oldest"
          : "${_game.currentPlayer}'s turn";
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: (has3Pieces || isRelocate) ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(double size) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
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
      },
    );
  }

  Widget _buildCell(int index, int row, int col) {
    final value = _game.board[index];
    final isWinCell = _game.winningCells.contains(index);
    final color = _playerColor(value);

    // Oldest piece indicators in FIFO mode
    final isOldest = _game.isOldestPiece(index);
    final isCurrentOldest = _game.isCurrentPlayerOldest(index);

    // Relocate mode indicators
    final isRelocate = _game.rule == BoardRule.relocate;
    final isSelected = isRelocate && _game.selectedPiece == index;
    final isRelocatePhase = isRelocate && !_game.isGameOver && _game.pieceCount(_game.currentPlayer) >= 3;
    final isSelectable = isRelocatePhase && value == _game.currentPlayer && !isSelected;
    final isValidTarget = isRelocate && !_game.isGameOver && _game.selectedPiece != null && value == null;

    // Border logic for grid lines
    final showRight = col < 2;
    final showBottom = row < 2;

    Color cellBgColor = Colors.transparent;
    if (isWinCell) {
      cellBgColor = color.withAlpha(25);
    } else if (isSelected) {
      cellBgColor = color.withAlpha(45);
    } else if (isOldest && !_game.isGameOver) {
      cellBgColor = color.withAlpha(isCurrentOldest ? 18 : 8);
    } else if (isValidTarget) {
      cellBgColor = _playerColor(_game.currentPlayer).withAlpha(15);
    }

    return GestureDetector(
      key: ValueKey('cell_$index'),
      behavior: HitTestBehavior.opaque,
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
          color: cellBgColor,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Warning badge on oldest piece (FIFO mode)
            if (isOldest && !_game.isGameOver && value != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isCurrentOldest ? 45 : 20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withAlpha(isCurrentOldest ? 160 : 70),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 9,
                        color: color.withAlpha(isCurrentOldest ? 240 : 140),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isCurrentOldest ? 'NEXT' : '3RD',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: color.withAlpha(isCurrentOldest ? 240 : 140),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Relocate mode: Selected piece badge
            if (isSelected && !_game.isGameOver)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 9, color: color),
                      const SizedBox(width: 2),
                      Text(
                        'MOVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Relocate mode: Selectable marker subtle hint
            if (isSelectable)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.pan_tool_alt_outlined,
                  size: 11,
                  color: color.withAlpha(120),
                ),
              ),

            // Cell content (symbol or empty hint / valid target)
            Center(
              child: value != null
                  ? ScaleTransition(
                      scale: _cellScales[index],
                      child: _buildSymbol(value, isWinCell, isOldest, isCurrentOldest, isSelected),
                    )
                  : isValidTarget
                      ? _buildValidTargetHint(_playerColor(_game.currentPlayer))
                      : _game.isGameOver
                          ? const SizedBox.shrink()
                          : _buildEmptyHint(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidTargetHint(Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withAlpha((_pulseAnimation.value * 255).round()),
          width: 2,
        ),
        color: color.withAlpha(20),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSymbol(String value, bool isWinCell, bool isOldest, bool isCurrentOldest, bool isSelected) {
    final color = _playerColor(value);
    final double opacity = isWinCell || isSelected
        ? 1.0
        : isCurrentOldest
            ? _pulseAnimation.value
            : (isOldest ? 0.4 : 0.95);

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _lineColor,
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_game.winner != null) {
      final color = _playerColor(_game.winner);
      final winText = widget.gameMode == GameMode.vsBot
          ? (_game.winner == _playerSymbol ? '🎉 You Won!' : '🤖 Bot Won!')
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
    final isVsBot = widget.gameMode == GameMode.vsBot;
    final String buttonText;
    if (_game.isGameOver) {
      if (isVsBot) {
        buttonText = 'Next Match (${_playerSymbol == 'X' ? 'Play 2nd' : 'Play 1st'})';
      } else {
        buttonText = 'Next Match';
      }
    } else {
      buttonText = 'New Game';
    }

    return GestureDetector(
      key: const ValueKey('reset_button'),
      behavior: HitTestBehavior.opaque,
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
