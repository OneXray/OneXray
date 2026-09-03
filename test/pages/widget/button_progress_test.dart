import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/widget/button_progress.dart';

void main() {
  testWidgets('button progress keeps its label and fits the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: FilledButton(
              onPressed: null,
              child: ButtonProgress(
                busy: true,
                child: Text('Save configuration'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Save configuration'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
