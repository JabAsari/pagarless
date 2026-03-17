class Card {
  final int? id; // ID de Supabase
  final String alias;
  final String last4Digits;
  final String number; // Número completo
  final String expiryDate;
  final String cvc;
  final String network; // Visa, Mastercard, etc.
  final DateTime createdAt;

  Card({
    this.id,
    required this.alias,
    required this.last4Digits,
    required this.number,
    required this.expiryDate,
    required this.cvc,
    required this.network,
    required this.createdAt,
  });

  // Constructor para crear un objeto Card desde el mapa que nos da Supabase
  factory Card.fromMap(Map<String, dynamic> map) {
    return Card(
      id: map['id'],
      alias: map['alias'] as String,
      last4Digits: map['last_4_digits'] as String? ?? '',
      number: map['number'] as String? ?? '',
      expiryDate: map['expiry_date'] as String? ?? '',
      cvc: map['cvc'] as String? ?? '',
      network: map['network'] as String? ?? 'Desconocida',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}