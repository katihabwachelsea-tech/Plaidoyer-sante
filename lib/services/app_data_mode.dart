import 'mock_demo_data.dart';
import 'mock_medecin_data.dart';

class AppDataMode {
  AppDataMode._();

  static bool get useMockData =>
      MockDemoDataService.isEnabled || MockMedecinDataService.isEnabled;

  static void enableDemoMode() {
    MockDemoDataService.setDemoModeOnly();
    MockMedecinDataService.setDemoModeOnly();
  }

  static void enableProductionMode() {
    MockDemoDataService.setProductionMode();
    MockMedecinDataService.setProductionMode();
  }

  static void setMode(bool useMock) {
    if (useMock) {
      enableDemoMode();
    } else {
      enableProductionMode();
    }
  }
}
