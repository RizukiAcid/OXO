enum GameMode {
  localMultiplayer,
  vsBot,
  ultimateLocalMultiplayer,
  ultimateVsBot,
}

enum BoardRule {
  classic,
  fifo,
}

extension BoardRuleExtension on BoardRule {
  String get label {
    switch (this) {
      case BoardRule.classic:
        return 'Classic';
      case BoardRule.fifo:
        return '3-Piece FIFO';
    }
  }

  String get description {
    switch (this) {
      case BoardRule.classic:
        return 'Standard Tic-Tac-Toe rules';
      case BoardRule.fifo:
        return 'Max 3 pieces per player. 4th move evicts oldest piece.';
    }
  }
}

enum BotDifficulty {
  easy,
  medium,
  hard,
}

extension BotDifficultyExtension on BotDifficulty {
  String get label {
    switch (this) {
      case BotDifficulty.easy:
        return 'Casual';
      case BotDifficulty.medium:
        return 'Balanced';
      case BotDifficulty.hard:
        return 'Unbeatable';
    }
  }

  String get description {
    switch (this) {
      case BotDifficulty.easy:
        return 'Makes occasional mistakes';
      case BotDifficulty.medium:
        return 'A fair challenge';
      case BotDifficulty.hard:
        return 'Impossible to defeat';
    }
  }
}
