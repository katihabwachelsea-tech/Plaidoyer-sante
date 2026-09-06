// lib /models/patient.dart

class Patient {
  final int? id;
  final int? serverId;
  final String nom;
  final String prenom;
  final int age;
  final String pays;
  final String maladie;
  String? conseils;
  final DateTime dateCreation;
  final DateTime? derniereVisite;
  final DateTime? updatedAt;

  Patient({
    this.id,
    this.serverId,
    required this.nom,
    required this.prenom,
    required this.age,
    required this.pays,
    required this.maladie,
    this.conseils,
    DateTime? dateCreation,
    this.derniereVisite,
    this.updatedAt,
  }) : dateCreation = dateCreation ?? DateTime.now();

  // convertir Patient vers Map (pour SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'nom': nom,
      'prenom': prenom,
      'age': age,
      'pays': pays,
      'maladie': maladie,
      'conseils': conseils,
      'dateCreation': dateCreation.toIso8601String(),
      'derniereVisite': derniereVisite?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Payload pour l'API Laravel (snake_case)
  Map<String, dynamic> toApiMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'age': age,
      'pays': pays,
      'maladie': maladie,
      'conseils': conseils,
      'date_creation': dateCreation.toIso8601String(),
      if (derniereVisite != null)
        'derniere_visite': derniereVisite!.toIso8601String(),
    };
  }

  // créé Patient depuis Map (depuis SQLite)
  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      serverId: map['server_id'] is int
          ? map['server_id'] as int
          : int.tryParse('${map['server_id']}'),
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      age: map['age']?.toInt() ?? 0,
      pays: map['pays'] ?? '',
      maladie: map['maladie'] ?? '',
      conseils: map['conseils'],
      dateCreation: _parseDate(map['dateCreation'] ?? map['date_creation']),
      derniereVisite: map['derniereVisite'] != null || map['derniere_visite'] != null
          ? _parseDate(map['derniereVisite'] ?? map['derniere_visite'])
          : null,
      updatedAt: map['updated_at'] != null
          ? _parseDate(map['updated_at'])
          : null,
    );
  }

  /// Depuis la réponse JSON Laravel
  factory Patient.fromApiMap(Map<String, dynamic> map) {
    final serverId = map['id'] is int ? map['id'] as int : int.parse('${map['id']}');
    return Patient(
      id: serverId,
      serverId: serverId,
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      age: map['age']?.toInt() ?? 0,
      pays: map['pays'] ?? '',
      maladie: map['maladie'] ?? '',
      conseils: map['conseils'],
      dateCreation: _parseDate(map['date_creation'] ?? map['created_at']),
      derniereVisite: map['derniere_visite'] != null
          ? _parseDate(map['derniere_visite'])
          : null,
      updatedAt: map['updated_at'] != null ? _parseDate(map['updated_at']) : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    final str = value.toString();
    if (str.length >= 10 && !str.contains('T') && !str.contains(' ')) {
      return DateTime.parse('${str.substring(0, 10)}T00:00:00');
    }
    return DateTime.parse(str.replaceFirst(' ', 'T'));
  }

  int? get syncId => serverId ?? id;
  //  créé une copie avec des modifications
  Patient copyWith({
    int? id,
    int? serverId,
    String? nom,
    String? prenom,
    int? age,
    String? pays,
    String? maladie,
    String? conseils,
    DateTime? dateCreation,
    DateTime? derniereVisite,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      age: age ?? this.age,
      pays: pays ?? this.pays,
      maladie: maladie ?? this.maladie,
      conseils: conseils ?? this.conseils,
      dateCreation: dateCreation ?? this.dateCreation,
      derniereVisite: derniereVisite ?? this.derniereVisite,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Nom complet pour l'affichage
  String get nomComplet => '$prenom $nom';
  // statut basé sur la dernière visite
  String get statut {
    if (derniereVisite == null) return 'Nouveau';

    final joursDepuisVisite = DateTime.now().difference(derniereVisite!).inDays;

    if (joursDepuisVisite <= 7) return 'Récent';
    if (joursDepuisVisite <= 30) return 'Stable';
    return 'A revoir';
  }

  @override
  String toString() {
    return 'Patient{id: $id, nom: $nomComplet, pays: $pays, maladie: $maladie}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Patient && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
