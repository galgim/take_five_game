import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five_game/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TakeFiveApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
