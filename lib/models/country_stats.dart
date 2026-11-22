// Mettez cette classe dans un fichier comme '../models/country_stats.dart'
class CountryStats {
  final int? id;
  final String countryCode;
  final String countryName;
  final double value;
  final int year;
  final String indicator;
  final String indicatorDimension;
  final DateTime lastUpdated;

  CountryStats({
    this.id,
    required this.countryCode,
    required this.countryName,
    required this.value,
    required this.year,
    required this.indicator,
    required this.indicatorDimension,
    required this.lastUpdated,
  });

  // Convertir un objet Map (lu depuis la DB) en objet CountryStats
  factory CountryStats.fromMap(Map<String, dynamic> map) {
    return CountryStats(
      id: map['id'] as int?,
      countryCode: map['countryCode'] as String,
      countryName: map['countryName'] as String,
      value: map['value'] as double,
      year: map['year'] as int,
      indicator: map['indicator'] as String,
      indicatorDimension: map['indicatorDimension'] as String,
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  // Convertir l'objet CountryStats en Map pour l'insertion/mise à jour dans la DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'countryCode': countryCode,
      'countryName': countryName,
      'value': value,
      'year': year,
      'indicator': indicator,
      'indicatorDimension': indicatorDimension,
      'lastUpdated': lastUpdated
          .toIso8601String(), // ⚠️ Rappel : Stocker au format ISO8601 pour DB
    };
  }

  factory CountryStats.fromWHOJson(Map<String, dynamic> json) {
    return CountryStats(
      countryCode: json['SpatialDim'] ?? '',
      countryName: json['SpatialDimValueCode'] ?? '',
      value: double.tryParse(json['NumericValue']?.toString() ?? '0') ?? 0.0,
      year:
          int.tryParse(json['TimeDim']?.toString() ?? '0') ??
          DateTime.now().year,
      indicator: json['IndicatorCode'] ?? '',
      indicatorDimension: json['indicatorDimension'] ?? '',
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CountryStats{$countryName: $value ($year)}';
  }
}
