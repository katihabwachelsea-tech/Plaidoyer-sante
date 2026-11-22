class MedecinPatient {
  final int id;
  final int medecinId;
  final String nom;
  final String prenom;
  final int? age;
  final String? pays;
  final String? maladie;
  final String? notes;
  final DateTime? dateCreation;
  final DateTime? derniereVisite;

  const MedecinPatient({
    required this.id,
    required this.medecinId,
    required this.nom,
    required this.prenom,
    this.age,
    this.pays,
    this.maladie,
    this.notes,
    this.dateCreation,
    this.derniereVisite,
  });

  factory MedecinPatient.fromJson(Map<String, dynamic> json) {
    return MedecinPatient(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      medecinId: json['medecin_id'] is int
          ? json['medecin_id'] as int
          : int.parse('${json['medecin_id']}'),
      nom: (json['nom'] ?? '').toString(),
      prenom: (json['prenom'] ?? '').toString(),
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse('${json['age']}'),
      pays: json['pays']?.toString(),
      maladie: json['maladie']?.toString(),
      notes: json['conseils']?.toString(),
      dateCreation: json['date_creation'] != null
          ? DateTime.tryParse(json['date_creation'].toString())
          : null,
      derniereVisite: json['derniere_visite'] != null
          ? DateTime.tryParse(json['derniere_visite'].toString())
          : null,
    );
  }
}
