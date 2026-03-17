import 'package:flutter/material.dart';
import 'package:pagarless/collections/saving.dart';

class SavingsTab extends StatelessWidget {
  final List<Saving> savings;
  const SavingsTab({super.key, this.savings = const []});

  @override
  Widget build(BuildContext context) {
    if (savings.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: savings.length,
        itemBuilder: (context, index) {
          final item = savings[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: const Icon(Icons.savings, color: Colors.green)),
              title: Text(item.name),
              subtitle: Text('Objetivo: \$${item.targetAmount.toStringAsFixed(2)}'),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 80, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          const Text("Ahorros y Recordatorios", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Define tus metas y alertas aquí.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}