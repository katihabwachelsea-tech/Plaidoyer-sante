import '../models/country_stats.dart';
import '../models/patient.dart';
import '../utils/doctor_photo.dart';

class MockDemoDataService {
  MockDemoDataService._internal();

  static final MockDemoDataService instance = MockDemoDataService._internal();

  static bool demoMode = true;

  static void setDemoMode(bool enabled) {
    demoMode = enabled;
  }

  static bool get isEnabled => demoMode;

  static void setProductionMode() => demoMode = false;
  static void setDemoModeOnly() => demoMode = true;

  List<Patient> get patients => [
    Patient(
      id: 1,
      nom: 'Niyonkuru',
      prenom: 'Aline',
      age: 29,
      pays: 'Burundi',
      maladie: 'Diabète',
      conseils: 'Suivre le traitement, boire beaucoup d’eau et respecter le suivi nutritionnel.',
      dateCreation: DateTime.now().subtract(const Duration(days: 1)),
      derniereVisite: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Patient(
      id: 2,
      nom: 'Mugisha',
      prenom: 'Joseph',
      age: 41,
      pays: 'Rwanda',
      maladie: 'Hypertension',
      conseils: 'Contrôler la pression, limiter le sel et faire une marche quotidienne.',
      dateCreation: DateTime.now().subtract(const Duration(days: 4)),
      derniereVisite: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Patient(
      id: 3,
      nom: 'Kamanzi',
      prenom: 'Clémence',
      age: 34,
      pays: 'Kenya',
      maladie: 'Cancer du sein',
      conseils: 'Poursuivre le traitement, suivre les rendez-vous de contrôle et gérer le stress.',
      dateCreation: DateTime.now().subtract(const Duration(days: 9)),
      derniereVisite: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Patient(
      id: 4,
      nom: 'Sibomana',
      prenom: 'Emmanuel',
      age: 52,
      pays: 'Tanzania',
      maladie: 'Asthme',
      conseils: 'Éviter les irritants, faire les inhalations prescrites et suivre les contrôles.',
      dateCreation: DateTime.now().subtract(const Duration(days: 15)),
      derniereVisite: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  List<Map<String, dynamic>> get doctors => [
    {
      'id': 1,
      'nom': 'Dr. Aline Ndayisenga',
      'specialite': 'Cardiologie',
      'hopital': 'Clinique de l’Espérance',
      'disponibilite': 'Lundi - Vendredi, 08:00 - 16:00',
      'photo_url': kFemaleDoctorPhotos[0],
      'profileImageUrl': kFemaleDoctorPhotos[0],
      'user': {
        'nom': 'Dr. Aline Ndayisenga',
        'photo_url': kFemaleDoctorPhotos[0],
        'profileImageUrl': kFemaleDoctorPhotos[0],
      },
    },
    {
      'id': 2,
      'nom': 'Dr. Jean Mugenzi',
      'specialite': 'Endocrinologie',
      'hopital': 'Centre Médical Saint-Luc',
      'disponibilite': 'Lundi - Samedi, 09:00 - 17:00',
      'photo_url': kMaleDoctorPhotos[0],
      'profileImageUrl': kMaleDoctorPhotos[0],
      'user': {
        'nom': 'Dr. Jean Mugenzi',
        'photo_url': kMaleDoctorPhotos[0],
        'profileImageUrl': kMaleDoctorPhotos[0],
      },
    },
    {
      'id': 3,
      'nom': 'Dr. Mireille Uwimana',
      'specialite': 'Oncologie',
      'hopital': 'Hôpital de Kigali',
      'disponibilite': 'Mardi - Dimanche, 09:30 - 15:30',
      'photo_url': kFemaleDoctorPhotos[3],
      'profileImageUrl': kFemaleDoctorPhotos[3],
      'user': {
        'nom': 'Dr. Mireille Uwimana',
        'photo_url': kFemaleDoctorPhotos[3],
        'profileImageUrl': kFemaleDoctorPhotos[3],
      },
    },
    {
      'id': 4,
      'nom': 'Dr. Patrick Habimana',
      'specialite': 'Pédiatrie',
      'hopital': 'Centre de Santé de Butare',
      'disponibilite': 'Lundi - Vendredi, 07:30 - 14:30',
      'photo_url': kMaleDoctorPhotos[2],
      'profileImageUrl': kMaleDoctorPhotos[2],
      'user': {
        'nom': 'Dr. Patrick Habimana',
        'photo_url': kMaleDoctorPhotos[2],
        'profileImageUrl': kMaleDoctorPhotos[2],
      },
    },
    {
      'id': 5,
      'nom': 'Dr. Sandrine Iradukunda',
      'specialite': 'Gynécologie',
      'hopital': 'Maternité de Bujumbura',
      'disponibilite': 'Mardi - Samedi, 08:30 - 15:30',
      'photo_url': kFemaleDoctorPhotos[1],
      'profileImageUrl': kFemaleDoctorPhotos[1],
      'user': {
        'nom': 'Dr. Sandrine Iradukunda',
        'photo_url': kFemaleDoctorPhotos[1],
        'profileImageUrl': kFemaleDoctorPhotos[1],
      },
    },
    {
      'id': 6,
      'nom': 'Dr. Eric Kalisa',
      'specialite': 'Dermatologie',
      'hopital': 'Clinique Kigali Beauty Care',
      'disponibilite': 'Lundi - Jeudi, 10:00 - 18:00',
      'photo_url': kMaleDoctorPhotos[3],
      'profileImageUrl': kMaleDoctorPhotos[3],
      'user': {
        'nom': 'Dr. Eric Kalisa',
        'photo_url': kMaleDoctorPhotos[3],
        'profileImageUrl': kMaleDoctorPhotos[3],
      },
    },
  ];

  List<String> get specialties => [
    'Cardiologie',
    'Endocrinologie',
    'Oncologie',
    'Pédiatrie',
    'Gynécologie',
    'Dermatologie',
  ];

  List<CountryStats> get countryStats => [
    CountryStats(
      countryCode: 'BDI',
      countryName: 'Burundi',
      value: 145.0,
      year: 2025,
      indicator: 'NCDMORT3070',
      indicatorDimension: 'BothSexes',
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
    ),
    CountryStats(
      countryCode: 'RWA',
      countryName: 'Rwanda',
      value: 178.0,
      year: 2025,
      indicator: 'NCDMORT3070',
      indicatorDimension: 'BothSexes',
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    ),
    CountryStats(
      countryCode: 'KEN',
      countryName: 'Kenya',
      value: 234.0,
      year: 2025,
      indicator: 'NCDMORT3070',
      indicatorDimension: 'BothSexes',
      lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
    ),
    CountryStats(
      countryCode: 'TZA',
      countryName: 'Tanzania',
      value: 189.0,
      year: 2025,
      indicator: 'NCDMORT3070',
      indicatorDimension: 'BothSexes',
      lastUpdated: DateTime.now().subtract(const Duration(days: 4)),
    ),
    CountryStats(
      countryCode: 'UGA',
      countryName: 'Uganda',
      value: 167.0,
      year: 2025,
      indicator: 'NCDMORT3070',
      indicatorDimension: 'BothSexes',
      lastUpdated: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  Future<List<Patient>> getPatients({int limit = 5}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return patients.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getDoctorsList() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return doctors;
  }

  Future<List<String>> getSpecialtiesList() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return specialties;
  }

  Future<List<CountryStats>> getCountryStatsList() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return countryStats;
  }
}
