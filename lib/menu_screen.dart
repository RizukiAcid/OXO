import 'package:flutter/material.dart';
import 'game_mode.dart';
import 'game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  static const _bgColor = Color(0xFF12121F);
  static const _surfaceColor = Color(0xFF1E1E30);
  static const _accentX = Color(0xFF6C63FF); // Purple
  static const _accentO = Color(0xFFFF6584); // Rose
  static const _lineColor = Color(0xFF2E2E45);

  BotDifficulty _selectedDifficulty = BotDifficulty.medium;

  late AnimationController _headerController;
  late Animation<double> _headerScale;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _headerScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  void _startGame(GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gameMode: mode,
          difficulty: _selectedDifficulty,
        ),
      ),
    );
  }

  void _showDifficultyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: _lineColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accentO.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: _accentO, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Bot Difficulty',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Choose your challenge level',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...BotDifficulty.values.map((diff) {
                  final isSelected = _selectedDifficulty == diff;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setModalState(() {
                          _selectedDifficulty = diff;
                        });
                        setState(() {
                          _selectedDifficulty = diff;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? _accentO.withAlpha(25) : _bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? _accentO : _lineColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? _accentO : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    diff.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    diff.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? _accentO.withAlpha(200) : Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startGame(GameMode.vsBot);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentO,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Start Match',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Background ambient glow circles
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentX.withAlpha(20),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentO.withAlpha(20),
                ),
              ),
            ),

            // Main menu content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    ScaleTransition(
                      scale: _headerScale,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'O',
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: _accentO,
                              shadows: [
                                Shadow(
                                  color: _accentO.withAlpha(150),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'X',
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: _accentX,
                              shadows: [
                                Shadow(
                                  color: _accentX.withAlpha(150),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'O',
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: _accentO,
                              shadows: [
                                Shadow(
                                  color: _accentO.withAlpha(150),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'TIC TAC TOE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SELECT GAME MODE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Option 1: Local Multiplayer
                    _buildModeCard(
                      title: 'Local Multiplayer',
                      subtitle: 'Pass & Play with a friend locally',
                      icon: Icons.people_alt_rounded,
                      gradientColors: [_accentX, const Color(0xFF8B5CF6)],
                      badgeText: '2 Players',
                      onTap: () => _startGame(GameMode.localMultiplayer),
                    ),

                    const SizedBox(height: 20),

                    // Option 2: VS Bot
                    _buildModeCard(
                      title: 'VS Bot',
                      subtitle: 'Challenge smart AI (${_selectedDifficulty.label})',
                      icon: Icons.smart_toy_rounded,
                      gradientColors: [_accentO, const Color(0xFFFF8E53)],
                      badgeText: _selectedDifficulty.label,
                      badgeColor: _accentO,
                      onTap: _showDifficultyDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required String badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lineColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withAlpha(35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          highlightColor: gradientColors[0].withAlpha(30),
          splashColor: gradientColors[0].withAlpha(40),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? gradientColors[0]).withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (badgeColor ?? gradientColors[0]).withAlpha(100),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: badgeColor ?? gradientColors[0],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
