enum GameMode {
  localMultiplayer,
  vsBot,
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
