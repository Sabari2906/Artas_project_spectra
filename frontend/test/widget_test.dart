// Basic smoke test — updated to match new ThemeNotifier constructor
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_client/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminDashboardApp());
    expect(find.byType(AdminDashboardApp), findsOneWidget);
  });
}
