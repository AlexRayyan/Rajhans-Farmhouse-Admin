import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rajhans_farmhouse_admin/src/app.dart';

void main() {
  testWidgets('shows a safe fallback when startup is incomplete',
      (tester) async {
    await tester.pumpWidget(const RajhansApp(firebaseReady: false));
    expect(find.textContaining('App setup is incomplete'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
