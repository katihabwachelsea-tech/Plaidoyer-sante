class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.readAt,
    this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse('${json['user_id']}'),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'info').toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
