// lib/models/appointment.dart

class Appointment {
  final int id;
  final int medecinId;
  final int patientUserId;
  final int? creneauId;
  final String motif;
  final String statut;
  final String urgence;
  final List<String> piecesJointes;
  final DateTime dateHeure;
  final double? montant;
  final String? paymentRef;
  final String? patientNom;
  final String? patientEmail;
  final String? patientTelephone;
  final String? meetingUrl;
  final String? serviceMode;
  final String? serviceName;

  const Appointment({
    required this.id,
    required this.medecinId,
    required this.patientUserId,
    this.creneauId,
    required this.motif,
    required this.statut,
    this.urgence = 'Normal',
    this.piecesJointes = const [],
    required this.dateHeure,
    this.montant,
    this.paymentRef,
    this.patientNom,
    this.patientEmail,
    this.patientTelephone,
    this.meetingUrl,
    this.serviceMode,
    this.serviceName,
  });

  bool get isConfirme => statut == 'Confirme';
  bool get isTermine  => statut == 'Termine';
  bool get isPending  => statut == 'En_attente';
  bool get isAccepted => statut == 'Accepte';
  bool get isAnnule   => statut == 'Annule';

  bool get isUrgent     => urgence == 'Urgent';
  bool get isTresUrgent => urgence == 'Tres_urgent';
  bool get hasAttachments => piecesJointes.isNotEmpty;

  String get urgenceLabel => switch (urgence) {
    'Urgent'      => 'Urgent',
    'Tres_urgent' => 'Très urgent',
    _             => 'Normal',
  };
  bool get isTeleconsultation => serviceMode == 'teleconsultation';
  bool get canJoinTele =>
      isTeleconsultation &&
      isToday &&
      isConfirme &&
      (meetingUrl?.isNotEmpty ?? false);

  /// True si le RDV est prévu aujourd'hui (fuseau local appareil).
  bool get isToday {
    final local = dateHeure.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  /// Marge avant l'heure prévue (préparation cabinet).
  static const Duration consultationEarlyMargin = Duration(minutes: 5);

  /// True si on peut démarrer la consultation (jour J + heure atteinte).
  bool get canStartConsultation {
    if (!isConfirme || !isToday) return false;
    final start = dateHeure.toLocal().subtract(consultationEarlyMargin);
    return !DateTime.now().isBefore(start);
  }

  /// Minutes restantes avant l'heure de début (0 si déjà atteint / passé).
  int get minutesUntilStart {
    final start = dateHeure.toLocal();
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inMinutes;
  }

  String get patientDisplayName => patientNom ?? 'Patient #$patientUserId';

  factory Appointment.fromApiMap(Map<String, dynamic> map) {
    final patientUser = map['patient_user'] as Map<String, dynamic>?;
    final service = map['service'] as Map<String, dynamic>?;
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
      urgence: map['urgence'] as String? ?? 'Normal',
      piecesJointes: (map['pieces_jointes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dateHeure: DateTime.parse(
        (map['date_heure'] ?? map['date_rdv'] ?? map['created_at'])
            .toString()
            .replaceFirst(' ', 'T'),
      ).toLocal(),
      montant: map['montant'] != null
          ? double.tryParse('${map['montant']}')
          : null,
      paymentRef: map['payment_ref'] as String?,
      patientNom: patientUser?['nom'] as String?,
      patientEmail: patientUser?['email'] as String?,
      patientTelephone: patientUser?['telephone'] as String?,
      meetingUrl: map['meeting_url']?.toString(),
      serviceMode: service?['mode']?.toString(),
      serviceName: service?['nom_service']?.toString(),
    );
  }

  Appointment copyWith({String? statut}) => Appointment(
        id: id,
        medecinId: medecinId,
        patientUserId: patientUserId,
        creneauId: creneauId,
        motif: motif,
        statut: statut ?? this.statut,
        urgence: urgence,
        piecesJointes: piecesJointes,
        dateHeure: dateHeure,
        montant: montant,
        paymentRef: paymentRef,
        patientNom: patientNom,
        patientEmail: patientEmail,
        patientTelephone: patientTelephone,
        meetingUrl: meetingUrl,
        serviceMode: serviceMode,
        serviceName: serviceName,
      );

  /// Sérialisation cache SQLite (offline).
  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'medecin_id': medecinId,
        'patient_user_id': patientUserId,
        'creneau_id': creneauId,
        'motif': motif,
        'statut': statut,
        'urgence': urgence,
        'pieces_jointes': piecesJointes,
        'date_heure': dateHeure.toIso8601String(),
        'montant': montant,
        'payment_ref': paymentRef,
        'meeting_url': meetingUrl,
        'patient_user': {
          'nom': patientNom,
          'email': patientEmail,
          'telephone': patientTelephone,
        },
        'service': {
          'mode': serviceMode,
          'nom_service': serviceName,
        },
      };

  factory Appointment.fromCacheMap(Map<String, dynamic> map) =>
      Appointment.fromApiMap(map);
}

class Creneau {
  final int id;
  final int medecinId;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final bool disponible;
  final bool generatedByWorkingTime;

  const Creneau({
    required this.id,
    required this.medecinId,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.disponible,
    this.generatedByWorkingTime = false,
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
      generatedByWorkingTime: map['generated_by_working_time'] == true ||
          map['generated_by_working_time'] == 1,
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
  final String? photoUrl;

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
    this.photoUrl,
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
      nom: user?['nom'] as String? ?? map['nom'] as String?,
      email: user?['email'] as String? ?? map['email'] as String?,
      telephone: user?['telephone'] as String? ?? map['telephone'] as String?,
      photoUrl: user?['photo_url'] as String? ?? map['photo_url'] as String?,
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
