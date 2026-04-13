import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagarless/screens/wallet_tab.dart';
import 'package:pagarless/collections/card.dart' as my_card;

void main() {
  testWidgets('WalletTab muestra el mensaje vacío cuando no hay tarjetas', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WalletTab(cards: const [], onCardTapped: (_) {}),
      ),
    ));

    expect(find.text('Mi Wallet'), findsOneWidget);
    expect(find.text('Gestiona tus tarjetas de crédito.'), findsOneWidget);
  });

  testWidgets('WalletTab muestra una tarjeta cuando se le pasa en la lista', (WidgetTester tester) async {
    final testCard = my_card.Card(
      alias: 'Tarjeta Azul',
      last4Digits: '1234',
      number: '1234567812341234',
      expiryDate: '12/28',
      cvc: '123',
      network: 'VISA',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WalletTab(cards: [testCard], onCardTapped: (_) {}),
      ),
    ));

    expect(find.text('Tarjeta Azul'), findsOneWidget);
    expect(find.text('**** **** **** 1234'), findsOneWidget);
  });
}
