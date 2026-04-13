import 'package:flutter_test/flutter_test.dart';
import 'package:pagarless/collections/expense.dart';

void main() {
  group('Concepto Model Tests', () {
    test('Debe crear una instancia de Concepto correctamente', () {
      final now = DateTime.now();
      final expense = Concepto(
        title: 'Café',
        amount: 3.50,
        date: now,
      );

      expect(expense.title, 'Café');
      expect(expense.amount, 3.50);
      expect(expense.date, now);
    });

    test('Debe convertir Concepto a un mapa JSON correctamente', () {
      final date = DateTime.parse('2023-10-27T10:30:00Z');
      final expense = Concepto(
        title: 'Almuerzo',
        amount: 12.75,
        date: date,
      );
      final json = expense.toJson();
      expect(json, {'title': 'Almuerzo', 'amount': 12.75, 'date': '2023-10-27T10:30:00.000Z'});
    });
  });
}