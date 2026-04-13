import 'package:flutter_test/flutter_test.dart';
import 'package:pagarless/collections/saving.dart';

void main() {
  group('Saving Model Tests', () {
    test('Debe crear una instancia de Saving desde un mapa (Supabase)', () {
      final map = {
        'id': 1,
        'name': 'Ahorro Carro',
        'target_amount': 5000.0,
        'created_at': '2023-10-27T10:00:00Z',
      };

      final saving = Saving.fromMap(map);

      expect(saving.id, 1);
      expect(saving.name, 'Ahorro Carro');
      expect(saving.targetAmount, 5000.0);
      expect(saving.createdAt, isA<DateTime>());
      expect(saving.createdAt.year, 2023);
    });
  });
}
