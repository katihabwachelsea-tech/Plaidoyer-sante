class Invoice {
  final int id;
  final int appointmentId;
  final double montant;
  final String statutPaiement;
  final String? methodePaiement;
  final String? transactionId;

  const Invoice({
    required this.id,
    required this.appointmentId,
    required this.montant,
    required this.statutPaiement,
    this.methodePaiement,
    this.transactionId,
  });

  bool get isPaid => statutPaiement == 'Paye';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      appointmentId: json['appointment_id'] is int
          ? json['appointment_id'] as int
          : int.parse('${json['appointment_id']}'),
      montant: double.tryParse('${json['montant']}') ?? 0,
      statutPaiement: (json['statut_paiement'] ?? 'Non_paye').toString(),
      methodePaiement: json['methode_paiement']?.toString(),
      transactionId: json['transaction_id']?.toString(),
    );
  }
}
