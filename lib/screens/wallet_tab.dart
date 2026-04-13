import 'package:flutter/material.dart' hide Card;
import 'package:pagarless/collections/card.dart';

class WalletTab extends StatelessWidget {
  final List<Card> cards;
  final Function(Card card) onCardTapped;

  const WalletTab({
    super.key,
    this.cards = const [],
    required this.onCardTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (cards.isNotEmpty) {
      // Usamos ListView para una lista vertical donde las tarjetas se apilan
      return ListView.builder(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 100),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final networkUpper = card.network.toUpperCase();

          // Definir gradientes específicos por marca para mejorar la distinción visual
          final LinearGradient cardGradient;
          if (networkUpper.contains('VISA')) {
            cardGradient = LinearGradient(colors: [Colors.indigo.shade900, const Color(0xFF1A1F71)], begin: Alignment.topLeft, end: Alignment.bottomRight);
          } else if (networkUpper.contains('MASTERCARD')) {
            cardGradient = LinearGradient(colors: [Colors.grey.shade900, const Color(0xFFEB001B).withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight);
          } else if (networkUpper.contains('AMEX') || networkUpper.contains('AMERICAN')) {
            cardGradient = LinearGradient(colors: [const Color(0xFF2E77BC), const Color(0xFF00C6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
          } else {
            // Fallback al tema de la app si es desconocida
            cardGradient = LinearGradient(colors: [colorScheme.primary, colorScheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight);
          }

          // Define el widget del logo basado en la red
          final Widget networkLogo;
          if (networkUpper == 'VISA') {
            networkLogo = Image.asset('assets/images/visa_logo.png', height: 25, fit: BoxFit.contain);
          } else if (networkUpper == 'MASTERCARD') {
            networkLogo = Image.asset('assets/images/mastercard_logo.png', height: 40, fit: BoxFit.contain);
          } else {
            networkLogo = Text(
              card.network.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 18,
                shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
              ),
            );
          }

          return Align(
            heightFactor: 0.7, // Efecto de apilamiento: la siguiente tarjeta comienza al 70% de esta
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => onCardTapped(card),
              child: Container(
                height: 220, // Altura fija reducida para proporciones más realistas
                margin: const EdgeInsets.only(bottom: 10), // Margen reducido
              decoration: BoxDecoration(
                // Usa el gradiente dinámico que definimos arriba
                gradient: cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.nfc, color: Colors.white70, size: 30),
                      networkLogo,
                    ],
                  ),
                  const Spacer(),
                  Semantics(
                    label: "Tarjeta terminada en ${card.last4Digits}",
                    excludeSemantics: true,
                    child: Text(
                      "**** **** **** ${card.last4Digits}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black45, offset: Offset(1, 2), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          card.alias,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        label: "Expira el ${card.expiryDate}",
                        excludeSemantics: true,
                        child: Text(
                          "VALID ${card.expiryDate}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            ),
          );
        },
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 80, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(height: 16),
          const Text("Mi Wallet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Gestiona tus tarjetas de crédito.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}