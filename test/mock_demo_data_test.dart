import 'package:flutter_test/flutter_test.dart';
import 'package:examen/services/mock_demo_data.dart';

void main() {
  group('Mock demo data', () {
    test('demo mode is disabled by default in production paths', () {
      expect(MockDemoDataService.instance.isEnabled, isFalse);
    });

    test('demo catalog still exists for optional offline preview', () {
      final service = MockDemoDataService.instance;
      expect(service.doctors, isNotEmpty);
      expect(service.specialties, isNotEmpty);
    });
  });
}
