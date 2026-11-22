class Consultation {
  final int id;
  final int appointmentId;
  final String? anamnese;
  final String? examen;
  final String? diagnostic;
  final String? ordonnance;
  final String? conseilsIa;
  final String? signaturePath;
  final DateTime? dateConsultation;
  final Map<String, dynamic>? constantesVitales;
  final List<dynamic>? medicaments;
  final List<dynamic>? examensComplementaires;

  const Consultation({
    required this.id,
    required this.appointmentId,
    this.anamnese,
    this.examen,
    this.diagnostic,
    this.ordonnance,
    this.conseilsIa,
    this.signaturePath,
    this.dateConsultation,
    this.constantesVitales,
    this.medicaments,
    this.examensComplementaires,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      appointmentId: json['appointment_id'] is int
          ? json['appointment_id'] as int
          : int.parse('${json['appointment_id']}'),
      anamnese: json['anamnese']?.toString(),
      examen: json['examen']?.toString(),
      diagnostic: json['diagnostic']?.toString(),
      ordonnance: json['ordonnance']?.toString(),
      conseilsIa: json['conseils_ia']?.toString(),
      signaturePath: json['signature_path']?.toString(),
      dateConsultation: json['date_consultation'] != null
          ? DateTime.tryParse(json['date_consultation'].toString())
          : null,
      constantesVitales: json['constantes_vitales'] is Map
          ? Map<String, dynamic>.from(json['constantes_vitales'] as Map)
          : null,
      medicaments: json['medicaments'] is List
          ? List<dynamic>.from(json['medicaments'] as List)
          : null,
      examensComplementaires: json['examens_complementaires'] is List
          ? List<dynamic>.from(json['examens_complementaires'] as List)
          : null,
    );
  }
}
