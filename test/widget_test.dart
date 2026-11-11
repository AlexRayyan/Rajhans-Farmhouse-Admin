import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rajhans_farmhouse_admin/src/app.dart';

void main() {
  testWidgets('shows Firebase setup instructions when unconfigured', (tester) async {
    await tester.pumpWidget(const RajhansApp(firebaseReady: false));
    expect(find.textContaining('Firebase setup required'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
