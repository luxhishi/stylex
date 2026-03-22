import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylex/main.dart';

void main() {
  testWidgets('Stylex onboarding screens render', (WidgetTester tester) async {
    await tester.pumpWidget(const StylexApp());

    expect(find.text('Stylex'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('THE DIGITAL ATELIER'), findsOneWidget);
    expect(find.text('Login to Atelier'), findsOneWidget);
  });
}
