class Reminder {
  final int id;
  final String title;
  final double amount;
  final int? dayOfMonth; // Ahora puede ser nulo
  final bool isRecurring; // True = Mensual, False = Único
  final DateTime? targetDate; // Fecha para pagos únicos

  Reminder({
    required this.id,
    required this.title,
    required this.amount,
    this.dayOfMonth,
    required this.isRecurring,
    this.targetDate,
  });

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      dayOfMonth: map['day_of_month'] as int?,
      isRecurring: map['is_recurring'] as bool? ?? true,
      targetDate: map['target_date'] != null ? DateTime.parse(map['target_date']) : null,
    );
  }
}