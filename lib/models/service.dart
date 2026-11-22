class Service {
  final int id;
  final String nom;
  final double prix;
  final String mode;
  final String? specialite;

  const Service({
    required this.id,
    required this.nom,
    required this.prix,
    this.mode = 'presentiel',
    this.specialite,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      nom: (json['nom_service'] ?? '').toString(),
      prix: double.tryParse('${json['prix']}') ?? 0,
      mode: (json['mode'] ?? 'presentiel').toString(),
      specialite: json['specialite']?.toString(),
    );
  }
}
