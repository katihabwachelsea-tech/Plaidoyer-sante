class DeviceToken {
  final int id;
  final int userId;
  final String token;
  final String platform;
  final DateTime? lastUsedAt;

  const DeviceToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    this.lastUsedAt,
  });

  factory DeviceToken.fromJson(Map<String, dynamic> json) {
    return DeviceToken(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse('${json['user_id']}'),
      token: (json['token'] ?? '').toString(),
      platform: (json['platform'] ?? '').toString(),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
    );
  }
}
