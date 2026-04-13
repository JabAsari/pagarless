import 'package:flutter/material.dart';

class NotificationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const NotificationsTab({super.key, this.history = const []});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text("Sin notificaciones", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
            const Text("Aquí verás tus recordatorios pasados.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final date = DateTime.parse(item['created_at']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.history, color: Colors.white),
            ),
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Monto: \$${(item['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}\n'
              'Finalizado el: ${date.day}/${date.month}/${date.year}',
            ),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}