import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/country_stats.dart';
import '../models/patient.dart';
import 'api_logger.dart';
import 'db_service.dart'; // 💡 AJOUTEZ CET IMPORT

class WHOApiService {
  static const String _baseUrl = 'https://ghoapi.azureedge.net/api';
  static final WHOApiService instance = WHOApiService._internal();

  WHOApiService._internal();

  // Map pour convertir codes ISO -> noms lisibles
  static const Map<String, String> _countryNames = {
    'BDI': 'Burundi',
    'RWA': 'Rwanda',
    'KEN': 'Kenya',
    'TZA': 'Tanzania',
    'UGA': 'Uganda',
    'ETH': 'Ethiopia',
    'SOM': 'Somalia',
    'SSD': 'South Sudan',
    'COD': 'DR Congo',
    'MOZ': 'Mozambique',
  };

  // Méthode fictive pour récupérer des patients depuis l'API WHO
  Future<List<Patient>> getPatients() async {
    // ... (Logique inchangée)
    await Future.delayed(const Duration(seconds: 1));
    return [
      Patient(
        nom: 'Doe',
        prenom: 'John',
        age: 45,
        pays: 'Burundi',
        maladie: 'Cancer du poumon',
        conseils:
            'Manger équilibré, faire de l\'exercice, suivre le traitement',
        derniereVisite: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Patient(
        nom: 'Smith',
        prenom: 'Jane',
        age: 32,
        pays: 'Rwanda',
        maladie: 'VIH',
        conseils: 'Prendre les ARV régulièrement, manger sainement',
        derniereVisite: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Patient(
        nom: 'Uwimana',
        prenom: 'Marie',
        age: 28,
        pays: 'Burundi',
        maladie: 'Cancer du sein',
        conseils: 'Chimiothérapie, repos, soutien familial',
        derniereVisite: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  // Vérifier la connexion internet
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      // Augmentez le timeout
      final response = await http
          .get(Uri.parse('$_baseUrl'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e, st) {
      ApiLogger.error(url: _baseUrl, error: e, stackTrace: st);
      return false;
    }
  }

  // Récupérer statistiques cancer par pays
  Future<List<CountryStats>> getCancerStatsByCountry({
    List<String> countries = const [
      'BDI', // Burundi
      'RWA', // Rwanda
      'KEN', // Kenya
      'TZA', // Tanzania
      'UGA', // Uganda
      'ETH', // Ethiopia
      'SOM', // Somalia 'SSD', // South Sudan
      'COD', // DR Congo
      'MOZ', // Mozambique
    ],
    String?
    whoDimensionFilter, //  NOUVEAU PARAMÈTRE (Ex: 'BREAST' pour cancer du sein)
  }) async {
    try {
      if (!await hasInternetConnection()) {
        ApiLogger.fcm('WHO API — pas de connexion, données de test utilisées');
        return _getTestData();
      }

      final countryFilter = countries
          .map((c) => "SpatialDim eq '$c'")
          .join(' or ');
      String dimensionFilter = '';
      if (whoDimensionFilter != null && whoDimensionFilter.isNotEmpty) {
        dimensionFilter = " and Dim1 eq '$whoDimensionFilter'";
      }

      final filter = '($countryFilter$dimensionFilter)';
      final url = '$_baseUrl/NCDMORT3070?\$filter=$filter';

      ApiLogger.request(method: 'GET', url: url);
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'PlaidoyerSanteApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 30));
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> values = data['value'] ?? [];

        ApiLogger.fcm('WHO — ${values.length} résultats bruts reçus');

        // if (values.isEmpty) {
        //   print('Aucune donnée retournée - utilisation de données de test');
        //   return _getTestData();
        // }

        // Conversion de toutes les données en objets CountryStats
        List<CountryStats> allStats = [];
        for (var item in values) {
          try {
            final stat = CountryStats.fromWHOJson(item);
            // Convertir le code pays en nom lisible
            final readableName =
                _countryNames[stat.countryCode] ?? stat.countryCode;
            allStats.add(
              CountryStats(
                countryCode: stat.countryCode,
                countryName: readableName,
                value: stat.value,
                year: stat.year,
                indicator: stat.indicator,
                indicatorDimension: stat.indicatorDimension,
                lastUpdated: stat.lastUpdated,
              ),
            );
          } catch (e) {
            ApiLogger.fcm('WHO — erreur parsing item: $e');
          }
        }

        //  MODIFICATION 2 : Logique de FILTRAGE PAR ANNÉE (Année la plus récente)

        // Trouver l'année maximale parmi les résultats
        int maxYear = allStats.fold(
          0,
          (currentMax, stat) =>
              (stat.year ?? 0) > currentMax ? (stat.year ?? 0) : currentMax,
        );

        // Si l'année la plus récente est trouvée (et que ce n'est pas 0)
        List<CountryStats> filteredStats;
        if (maxYear > 0) {
          filteredStats = allStats
              .where((stat) => stat.year == maxYear)
              .toList();
          ApiLogger.fcm('WHO — ${filteredStats.length} données année $maxYear conservées');
        } else {
          filteredStats = allStats;
          ApiLogger.fcm('WHO — aucune année trouvée, ${filteredStats.length} données conservées');
        }

        return filteredStats.isEmpty ? _getTestData() : filteredStats;
      } else {
        return _getTestData();
      }
    } catch (e, st) {
      ApiLogger.error(url: '$_baseUrl/NCDMORT3070', error: e, stackTrace: st);
      return _getTestData();
    }
  }

  // Données de test pour le développement/offline
  List<CountryStats> _getTestData() {
    // ... (Logique inchangée)
    return [
      CountryStats(
        countryCode: 'BDI',
        countryName: 'Burundi',
        value: 145.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'RWA',
        countryName: 'Rwanda',
        value: 178.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'KEN',
        countryName: 'Kenya',
        value: 234.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'TZA',
        countryName: 'Tanzania',
        value: 189.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'UGA',
        countryName: 'Uganda',
        value: 167.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'ETH',
        countryName: 'Ethiopia',
        value: 156.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'SOM',
        countryName: 'Somalia',
        value: 198.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'SSD',
        countryName: 'South Sudan',
        value: 212.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'COD',
        countryName: 'DR Congo',
        value: 176.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
      CountryStats(
        countryCode: 'MOZ',
        countryName: 'Mozambique',
        value: 203.0,
        year: 2025,
        indicator: 'NCDMORT3070',
        indicatorDimension: 'BothSexes',
        lastUpdated: DateTime.now(),
      ),
    ];
  }

  // Récupérer tous les indicateurs de santé disponibles
  Future<List<HealthIndicator>> getAvailableIndicators() async {
    // ... (Logique inchangée)
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/Indicator'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> indicators = data['value'] ?? [];

        return indicators
            .map((item) => HealthIndicator.fromJson(item))
            .where(
              (indicator) =>
                  indicator.title.toLowerCase().contains('cancer') ||
                  indicator.title.toLowerCase().contains('mortality'),
            )
            .toList();
      } else {
        throw Exception(
          'Erreur récupération indicateurs: ${response.statusCode}',
        );
      }
    } catch (e, st) {
      ApiLogger.error(url: '$_baseUrl/indicators', error: e, stackTrace: st);
      return [];
    }
  }

  Future<void> syncAndSaveCancerStats() async {
    ApiLogger.fcm('WHO — Démarrage synchronisation');
    try {
      final List<CountryStats> retrievedStats = await getCancerStatsByCountry();
      if (retrievedStats.isNotEmpty) {
        await DatabaseService.instance.saveCountryStats(retrievedStats);
        ApiLogger.fcm('WHO — ${retrievedStats.length} stats sauvegardées');
      } else {
        ApiLogger.fcm('WHO — aucune statistique récupérée');
      }
    } catch (e, st) {
      ApiLogger.error(url: '$_baseUrl/NCDMORT3070', error: e, stackTrace: st);
    }
  }
}

// Modèle pour les indicateurs de santé
class HealthIndicator {
  // ... (Logique inchangée)
  final String code;
  final String title;
  final String definition;

  HealthIndicator({
    required this.code,
    required this.title,
    required this.definition,
  });

  factory HealthIndicator.fromJson(Map<String, dynamic> json) {
    return HealthIndicator(
      code: json['IndicatorCode'] ?? '',
      title: json['IndicatorName'] ?? '',
      definition: json['Definition'] ?? '',
    );
  }

  @override
  String toString() => '$code: $title';
}
