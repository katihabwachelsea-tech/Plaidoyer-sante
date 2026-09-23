// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:examen/main.dart';

void main() {
  testWidgets('App smoke test — LoginPage charge', (WidgetTester tester) async {
    await tester.pumpWidget(const MobClinicApp());
    await tester.pump();
    // Vérifie simplement que l'app démarre sans exception
    expect(find.byType(MobClinicApp), findsOneWidget);
  });
}
