class MedecinWorkingTime {
  final int medecinId;
  final int globalDurationMinutes;
  final List<dynamic> days;
  final List<dynamic> exceptions;

  const MedecinWorkingTime({
    required this.medecinId,
    required this.globalDurationMinutes,
    required this.days,
    required this.exceptions,
  });

  factory MedecinWorkingTime.fromJson(Map<String, dynamic> json) {
    return MedecinWorkingTime(
      medecinId: json['medecin_id'] is int
          ? json['medecin_id'] as int
          : int.parse('${json['medecin_id']}'),
      globalDurationMinutes: json['global_duration_minutes'] is int
          ? json['global_duration_minutes'] as int
          : int.tryParse('${json['global_duration_minutes']}') ?? 30,
      days: json['days'] is List
          ? List<dynamic>.from(json['days'] as List)
          : const [],
      exceptions: json['exceptions'] is List
          ? List<dynamic>.from(json['exceptions'] as List)
          : const [],
    );
  }
}
