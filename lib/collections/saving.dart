class Saving {
  final int? id; // ID de Supabase (puede ser nulo si aún no se ha guardado)
  final String name;
  final double targetAmount;
  final DateTime createdAt;

  Saving({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.createdAt,
  });

  // Constructor para crear un objeto Saving desde el mapa que nos da Supabase
  factory Saving.fromMap(Map<String, dynamic> map) {
    return Saving(
      id: map['id'],
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}