import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxo/game_mode.dart';
import 'package:oxo/game_screen.dart';
import 'package:oxo/menu_screen.dart';

void main() {
  testWidgets('Alternating turns test: Play 1st (X) -> Next match Play 2nd (O) -> Next match Play 1st (X)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          gameMode: GameMode.vsBot,
          difficulty: BotDifficulty.easy,
          playerSymbol: 'X',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Match 1: Player starts as X
    expect(find.text('Your turn (X)'), findsOneWidget);
    expect(find.text('YOU (X)'), findsOneWidget);
    expect(find.text('BOT (O)'), findsOneWidget);

    // Play until game is over
    for (int i = 0; i < 9; i++) {
      if (find.text('Next Match (Play 2nd)').evaluate().isNotEmpty) break;
      await tester.tap(find.byKey(ValueKey('cell_$i')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    // Match 1 ended!
    expect(find.text('Next Match (Play 2nd)'), findsOneWidget);

    // Tap reset button to start Match 2
    await tester.tap(find.byKey(const ValueKey('reset_button')));
    await tester.pump();

    // Match 2: Player is now O, Bot is X
    expect(find.text('YOU (O)'), findsOneWidget);
    expect(find.text('BOT (X)'), findsOneWidget);

    // Bot makes move
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Your turn (O)'), findsOneWidget);

    // Play until Match 2 is over
    for (int i = 0; i < 9; i++) {
      if (find.text('Next Match (Play 1st)').evaluate().isNotEmpty) break;
      await tester.tap(find.byKey(ValueKey('cell_$i')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    // Match 2 ended!
    expect(find.text('Next Match (Play 1st)'), findsOneWidget);

    // Tap reset button to start Match 3
    await tester.tap(find.byKey(const ValueKey('reset_button')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Match 3: Player is now X, Bot is O
    expect(find.text('YOU (X)'), findsOneWidget);
    expect(find.text('BOT (O)'), findsOneWidget);
    expect(find.text('Your turn (X)'), findsOneWidget);
  });

  testWidgets('Play 2nd (O) -> Next match Play 1st (X)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          gameMode: GameMode.vsBot,
          difficulty: BotDifficulty.easy,
          playerSymbol: 'O',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Match 1: Player is O, Bot started as X
    expect(find.text('YOU (O)'), findsOneWidget);
    expect(find.text('BOT (X)'), findsOneWidget);
    expect(find.text('Your turn (O)'), findsOneWidget);

    // Play until Match 1 is over
    for (int i = 0; i < 9; i++) {
      if (find.text('Next Match (Play 1st)').evaluate().isNotEmpty) break;
      await tester.tap(find.byKey(ValueKey('cell_$i')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    expect(find.text('Next Match (Play 1st)'), findsOneWidget);

    // Tap reset button to start Match 2
    await tester.tap(find.byKey(const ValueKey('reset_button')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Match 2: Player is now X (plays 1st)
    expect(find.text('YOU (X)'), findsOneWidget);
    expect(find.text('BOT (O)'), findsOneWidget);
    expect(find.text('Your turn (X)'), findsOneWidget);
  });

  testWidgets('MenuScreen updates playerSymbol when returning from completed match', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify initial MenuScreen state: Balanced • Play 1st
    expect(find.text('Challenge smart AI (Balanced • Play 1st)'), findsOneWidget);

    // Tap VS Bot card to open settings dialog
    await tester.tap(find.text('Challenge smart AI (Balanced • Play 1st)'));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap "Start Match"
    await tester.ensureVisible(find.text('Start Match'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start Match'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Now on GameScreen
    expect(find.text('YOU (X)'), findsOneWidget);

    // Play until match ends
    for (int i = 0; i < 9; i++) {
      if (find.text('Next Match (Play 2nd)').evaluate().isNotEmpty) break;
      await tester.tap(find.byKey(ValueKey('cell_$i')));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Next Match (Play 2nd)'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Back on MenuScreen: should now be Play 2nd!
    expect(find.text('Challenge smart AI (Balanced • Play 2nd)'), findsOneWidget);
  });
}
