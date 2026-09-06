// lib/models/user.dart

class User {
  final int? id;
  final String username;
  final String fullName;
  final String? email;
  final String? telephone;
  final String role; // 'admin', 'doctor', 'nurse', 'staff'
  final String? specialization;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  User({
    this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.telephone,
    required this.role,
    this.specialization,
    this.profileImageUrl,
    DateTime? createdAt,
    this.lastLogin,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  // Rôles disponibles
  // static const String roleAdmin = 'admin';
  static const String roleDoctor = 'medecin'; // Aligné avec Laravel
  static const String rolePatient = 'patient'; // Aligné avec Laravel
  static const String roleNurse = 'nurse';
  static const String roleStaff = 'staff';

  // Liste des rôles avec leurs labels
  static const Map<String, String> roleLabels = {
    // 'admin': 'Administrateur',
    'medecin': 'Médecin',
    'patient': 'Patient',
    'nurse': 'Infirmier(ère)',
    'staff': 'Personnel',
  };

  // Obtenir le label du rôle
  String get roleLabel => roleLabels[role] ?? role;

  // Vérifier si c'est un admin
  // bool get isAdmin => role == roleAdmin;

  // Vérifier si c'est un médecin
  bool get isDoctor => role == roleDoctor;

  // Obtenir les initiales
  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }

  // Convertir en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'email': email,
      'telephone': telephone,
      'role': role,
      'specialization': specialization,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  // Créer depuis Map/JSON (compatible SQLite et Laravel)
  factory User.fromMap(Map<String, dynamic> map) {
    final username = map['username'] as String? ?? map['email'] as String? ?? '';
    final fullName = map['fullName'] as String? ?? map['nom'] as String? ?? '';
    final createdAtValue = map['createdAt'] as String? ?? DateTime.now().toIso8601String();

    return User(
      id: map['id'] as int?,
      username: username,
      fullName: fullName,
      email: map['email'] as String?,
      telephone: map['telephone'] as String?,
      role: map['role'] as String,
      specialization: map['specialization'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      createdAt: DateTime.tryParse(createdAtValue) ?? DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? DateTime.parse(map['lastLogin'] as String)
          : null,
      isActive: map['isActive'] == null
          ? true
          : map['isActive'] is int
              ? (map['isActive'] as int) == 1
              : map['isActive'] as bool,
    );
  }

  /// Créer depuis JSON, utile pour les réponses API Laravel.
  factory User.fromJson(Map<String, dynamic> json) => User.fromMap(json);

  // Créer une copie avec modifications
  User copyWith({
    int? id,
    String? username,
    String? fullName,
    String? email,
    String? telephone,
    String? role,
    String? specialization,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, fullName: $fullName, role: $role}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id && other.username == username;
  }

  @override
  int get hashCode => id.hashCode ^ username.hashCode;
}