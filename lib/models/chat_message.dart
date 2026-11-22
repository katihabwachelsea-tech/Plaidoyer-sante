class ChatMessage {
  final int id;
  final int senderId;
  final String contenu;
  final String senderNom;
  final String senderRole;
  final bool isMine;
  final bool lu;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.contenu,
    required this.senderNom,
    required this.senderRole,
    required this.isMine,
    required this.lu,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      senderId: json['sender_id'] is int
          ? json['sender_id'] as int
          : int.parse('${json['sender_id']}'),
      contenu: (json['contenu'] ?? '').toString(),
      senderNom: (json['sender_nom'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? '').toString(),
      isMine: json['is_mine'] == true,
      lu: json['lu'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
