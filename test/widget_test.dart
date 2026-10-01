import 'package:flutter_test/flutter_test.dart';
import 'package:borrow_log/main.dart';

void main() {
  testWidgets('Borrow Log app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BorrowLogApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}