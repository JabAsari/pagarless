import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 0)
class Concepto extends HiveObject {
  // Hive maneja el ID internamente (se llama 'key'), no necesitamos declararlo explícitamente

  @HiveField(0)
  final String title;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  Concepto({
    required this.title,
    required this.amount,
    required this.date,
  });

  // Convierte el objeto a un Mapa (JSON) para enviarlo a Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(), // Firestore maneja bien las fechas en formato ISO
    };
  }
}