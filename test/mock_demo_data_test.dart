import 'package:flutter_test/flutter_test.dart';
import 'package:examen/services/mock_demo_data.dart';

void main() {
  group('Mock demo data', () {
    test('should expose doctors and specialties for UI demo', () {
      final service = MockDemoDataService.instance;

      expect(service.doctors, isNotEmpty);
      expect(service.specialties, isNotEmpty);
      expect(service.patients, isNotEmpty);
    });

    test('should keep demo mode enabled for design preview', () {
      expect(MockDemoDataService.instance.isEnabled, isTrue);
    });
  });
}
