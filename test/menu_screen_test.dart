import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxo/game_screen.dart';
import 'package:oxo/menu_screen.dart';
import 'package:oxo/ultimate_game_screen.dart';

void main() {
  testWidgets('Main menu shows exactly two mode options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify exactly 2 options on main menu
    expect(find.text('Local Multiplayer'), findsOneWidget);
    expect(find.text('VS Bot'), findsOneWidget);

    // Verify separate Ultimate cards no longer exist on main menu
    expect(find.text('Ultimate TTT'), findsNothing);
    expect(find.text('Ultimate TTT vs Bot'), findsNothing);
  });

  testWidgets('Local Multiplayer opens variant picker and launches Classic or Ultimate', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Local Multiplayer
    await tester.tap(find.text('Local Multiplayer'));
    await tester.pump(const Duration(milliseconds: 600));

    // Verify variant options in sheet
    expect(find.text('CHOOSE GAME VARIANT'), findsOneWidget);
    expect(find.text('Classic Tic Tac Toe'), findsOneWidget);
    expect(find.text('Ultimate Tic Tac Toe'), findsOneWidget);

    // Launch Classic
    await tester.ensureVisible(find.text('Classic Tic Tac Toe'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Classic Tic Tac Toe'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('LOCAL 2P'), findsOneWidget);

    // Go back to menu
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Local Multiplayer again
    await tester.tap(find.text('Local Multiplayer'));
    await tester.pump(const Duration(milliseconds: 600));

    // Launch Ultimate
    await tester.ensureVisible(find.text('Ultimate Tic Tac Toe'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Ultimate Tic Tac Toe'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(UltimateGameScreen), findsOneWidget);
  });

  testWidgets('VS Bot allows selecting Classic or Ultimate variant', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap VS Bot
    await tester.tap(find.text('VS Bot'));
    await tester.pump(const Duration(milliseconds: 600));

    // Verify GAME VARIANT section exists
    expect(find.text('GAME VARIANT'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Ultimate'), findsOneWidget);

    // Select Ultimate variant
    await tester.ensureVisible(find.text('Ultimate'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Ultimate'));
    await tester.pump(const Duration(milliseconds: 200));

    // Start match
    await tester.ensureVisible(find.text('Start Match'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start Match'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify UltimateGameScreen launched
    expect(find.byType(UltimateGameScreen), findsOneWidget);
  });
}
