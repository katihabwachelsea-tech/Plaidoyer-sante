// lib/models/conseil.dart

class Conseil {
  final int? id;
  final String titre;
  final String maladieCible; // Ex: 'Cancer du sein', 'Malaria'
  final String description;
  final String? source; // Ex: 'Santé nationale', 'Cabinet local'

  Conseil({
    this.id,
    required this.titre,
    required this.maladieCible,
    required this.description,
    this.source,
  });

  // Convertir Conseil vers Map (pour SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'maladieCible': maladieCible,
      'description': description,
      'source': source,
    };
  }

  // Créer Conseil depuis Map (depuis SQLite)
  factory Conseil.fromMap(Map<String, dynamic> map) {
    return Conseil(
      id: map['id']?.toInt(),
      titre: map['titre'] ?? '',
      maladieCible: map['maladieCible'] ?? '',
      description: map['description'] ?? '',
      source: map['source'] ?? '',
    );
  }

  @override
  String toString() {
    return 'Conseil{id: $id, titre: $titre, maladie: $maladieCible}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conseil && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
