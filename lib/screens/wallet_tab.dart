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
    if (cards.isNotEmpty) {
      // Usamos ListView para una lista vertical donde las tarjetas se apilan
      return ListView.builder(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 100),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];

          // Define el gradiente de color basado en la red de la tarjeta
          final LinearGradient cardGradient;
          if (card.network == 'VISA') {
            cardGradient = LinearGradient(colors: [Colors.indigo.shade900, Colors.lightBlue.shade300], begin: Alignment.topLeft, end: Alignment.bottomRight);
          } else if (card.network == 'MASTERCARD') {
            cardGradient = LinearGradient(colors: [Colors.red.shade900, Colors.orange.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight);
          } else {
            // Gradiente por defecto para otras redes o desconocidas
            cardGradient = LinearGradient(colors: [Colors.grey.shade900, Colors.blueGrey.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight);
          }

          // Define el widget del logo basado en la red
          final Widget networkLogo;
          if (card.network == 'VISA') {
            networkLogo = Image.asset('assets/images/visa_logo.png', height: 25, fit: BoxFit.contain);
          } else if (card.network == 'MASTERCARD') {
            networkLogo = Image.asset('assets/images/mastercard_logo.png', height: 40, fit: BoxFit.contain);
          } else {
            // Muestra el texto si no es Visa o Mastercard
            networkLogo = Text(card.network.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 18));
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
                  Text("**** **** **** ${card.last4Digits}", style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 3, fontFamily: 'monospace')),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(card.alias, style: const TextStyle(color: Colors.white70, fontSize: 18), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 10),
                      Text("VALID ${card.expiryDate}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
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