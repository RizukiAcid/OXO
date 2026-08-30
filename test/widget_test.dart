import 'package:flutter_test/flutter_test.dart';
import 'package:oxo/main.dart';

void main() {
  testWidgets('OXO App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OXOApp());

    // Verify that OXO title is displayed on MenuScreen
    expect(find.text('TIC TAC TOE'), findsOneWidget);
  });
}
