// Widget tests for Notes App

import 'package:flutter_test/flutter_test.dart';
import 'package:notes/main.dart';

void main() {
  testWidgets('App initializes successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NotesApp());

    // Verify that the app renders the home screen
    expect(find.text('Notes'), findsOneWidget);
  });
}
