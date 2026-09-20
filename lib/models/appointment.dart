// lib/models/appointment.dart

class Appointment {
  final int id;
  final int medecinId;
  final int patientUserId;
  final int? creneauId;
  final String motif;
  final String statut;
  final DateTime dateHeure;
  final double? montant;
  final String? paymentRef;
  final String? patientNom;
  final String? patientEmail;
  final String? patientTelephone;

  const Appointment({
    required this.id,
    required this.medecinId,
    required this.patientUserId,
    this.creneauId,
    required this.motif,
    required this.statut,
    required this.dateHeure,
    this.montant,
    this.paymentRef,
    this.patientNom,
    this.patientEmail,
    this.patientTelephone,
  });

  bool get isConfirme => statut == 'Confirme';
  bool get isTermine => statut == 'Termine';

  /// True si le RDV est prévu aujourd'hui (fuseau local appareil).
  bool get isToday {
    final local = dateHeure.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  String get patientDisplayName => patientNom ?? 'Patient #$patientUserId';

  factory Appointment.fromApiMap(Map<String, dynamic> map) {
    final patientUser = map['patient_user'] as Map<String, dynamic>?;
    return Appointment(
      id: map['id'] is int ? map['id'] as int : int.parse('${map['id']}'),
      medecinId: map['medecin_id'] is int
          ? map['medecin_id'] as int
          : int.parse('${map['medecin_id']}'),
      patientUserId: map['patient_user_id'] is int
          ? map['patient_user_id'] as int
          : int.parse('${map['patient_user_id']}'),
      creneauId: map['creneau_id'] != null
          ? (map['creneau_id'] is int
              ? map['creneau_id'] as int
              : int.tryParse('${map['creneau_id']}'))
          : null,
      motif: map['motif'] ?? '',
      statut: map['statut'] ?? 'En_attente',
      dateHeure: DateTime.parse(
        (map['date_heure'] ?? map['created_at']).toString().replaceFirst(' ', 'T'),
      ),
      montant: map['montant'] != null
          ? double.tryParse('${map['montant']}')
          : null,
      paymentRef: map['payment_ref'] as String?,
      patientNom: patientUser?['nom'] as String?,
      patientEmail: patientUser?['email'] as String?,
      patientTelephone: patientUser?['telephone'] as String?,
    );
  }
}

class Creneau {
  final int id;
  final int medecinId;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final bool disponible;

  const Creneau({
    required this.id,
    required this.medecinId,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.disponible,
  });

  factory Creneau.fromApiMap(Map<String, dynamic> map) {
    return Creneau(
      id: map['id'] is int ? map['id'] as int : int.parse('${map['id']}'),
      medecinId: map['medecin_id'] is int
          ? map['medecin_id'] as int
          : int.parse('${map['medecin_id']}'),
      date: DateTime.parse(map['date'].toString().substring(0, 10)),
      heureDebut: map['heure_debut']?.toString().substring(0, 5) ?? '',
      heureFin: map['heure_fin']?.toString().substring(0, 5) ?? '',
      disponible: map['disponible'] == true || map['disponible'] == 1,
    );
  }
}

class MedecinProfile {
  final int id;
  final int userId;
  final String specialite;
  final String? licence;
  final String hopital;
  final String? biographie;
  final String? disponibilite;
  final String? nom;
  final String? email;
  final String? telephone;

  const MedecinProfile({
    required this.id,
    required this.userId,
    required this.specialite,
    this.licence,
    required this.hopital,
    this.biographie,
    this.disponibilite,
    this.nom,
    this.email,
    this.telephone,
  });

  factory MedecinProfile.fromApiMap(Map<String, dynamic> map) {
    final user = map['user'] as Map<String, dynamic>?;
    return MedecinProfile(
      id: map['id'] is int ? map['id'] as int : int.parse('${map['id']}'),
      userId: map['user_id'] is int
          ? map['user_id'] as int
          : int.parse('${map['user_id']}'),
      specialite: map['specialite'] ?? '',
      licence: map['licence'] as String?,
      hopital: map['hopital'] ?? '',
      biographie: map['biographie'] as String?,
      disponibilite: map['disponibilite'] as String?,
      nom: user?['nom'] as String?,
      email: user?['email'] as String?,
      telephone: user?['telephone'] as String?,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        if (nom != null) 'nom': nom,
        if (telephone != null) 'telephone': telephone,
        'specialite': specialite,
        'hopital': hopital,
        if (biographie != null) 'biographie': biographie,
        if (disponibilite != null) 'disponibilite': disponibilite,
      };
}
