import '../models/appointment.dart';

class MockMedecinDataService {
  MockMedecinDataService._internal();

  static final MockMedecinDataService instance = MockMedecinDataService._internal();

  static bool demoMode = true;

  static void setDemoMode(bool enabled) {
    demoMode = enabled;
  }

  static bool get isEnabled => demoMode;

  static void setProductionMode() => demoMode = false;
  static void setDemoModeOnly() => demoMode = true;

  List<Appointment> get appointments => [
    Appointment(
      id: 1,
      medecinId: 101,
      patientUserId: 201,
      motif: 'Suivi du diabète',
      statut: 'Confirme',
      dateHeure: DateTime.now().add(const Duration(hours: 2)),
      montant: 25000,
      paymentRef: 'PAY-2026-1042',
      patientNom: 'Aline Niyonkuru',
      patientEmail: 'aline@email.com',
      patientTelephone: '+257 79 123 456',
    ),
    Appointment(
      id: 2,
      medecinId: 101,
      patientUserId: 202,
      motif: 'Contrôle tension artérielle',
      statut: 'Confirme',
      dateHeure: DateTime.now().add(const Duration(days: 1, hours: 3)),
      montant: 22000,
      paymentRef: 'PAY-2026-1045',
      patientNom: 'Joseph Mugisha',
      patientEmail: 'joseph@email.com',
      patientTelephone: '+250 78 555 221',
    ),
    Appointment(
      id: 3,
      medecinId: 101,
      patientUserId: 203,
      motif: 'Consultation oncologie',
      statut: 'Confirme',
      dateHeure: DateTime.now().add(const Duration(days: 2, hours: 5)),
      montant: 30000,
      paymentRef: 'PAY-2026-1048',
      patientNom: 'Clémence Kamanzi',
      patientEmail: 'clemence@email.com',
      patientTelephone: '+254 71 222 333',
    ),
  ];

  List<Creneau> get creneaux => [
    Creneau(
      id: 1,
      medecinId: 101,
      date: DateTime.now(),
      heureDebut: '09:00',
      heureFin: '10:00',
      disponible: true,
    ),
    Creneau(
      id: 2,
      medecinId: 101,
      date: DateTime.now().add(const Duration(days: 1)),
      heureDebut: '11:00',
      heureFin: '12:00',
      disponible: true,
    ),
    Creneau(
      id: 3,
      medecinId: 101,
      date: DateTime.now().add(const Duration(days: 2)),
      heureDebut: '14:00',
      heureFin: '15:00',
      disponible: false,
    ),
    Creneau(
      id: 4,
      medecinId: 101,
      date: DateTime.now().add(const Duration(days: 3)),
      heureDebut: '16:00',
      heureFin: '17:00',
      disponible: true,
    ),
  ];

  MedecinProfile get profile => const MedecinProfile(
    id: 10,
    userId: 77,
    specialite: 'Cardiologie',
    licence: 'CARD-2548',
    hopital: 'Clinique de l’Espérance',
    biographie:
        'Médecin généraliste spécialisé en cardiologie et suivi des maladies chroniques.',
    disponibilite: 'Lundi-Vendredi • 08:00-17:00',
    nom: 'Dr. Aline Ndayisenga',
    email: 'aline@plaidoyersante.com',
    telephone: '+257 79 654 321',
  );

  Future<List<Appointment>> getAppointmentsDemo() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return appointments;
  }

  Future<int> getTodayAppointmentsCountDemo() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return appointments.length;
  }

  Future<List<Creneau>> getCreneauxDemo({String? from, String? to}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return creneaux;
  }

  Future<MedecinProfile> getProfileDemo() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return profile;
  }
}
