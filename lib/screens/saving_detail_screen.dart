import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pagarless/collections/saving.dart';

class SavingDetailScreen extends StatefulWidget {
  final Saving saving;
  const SavingDetailScreen({super.key, required this.saving});

  @override
  State<SavingDetailScreen> createState() => _SavingDetailScreenState();
}

class _SavingDetailScreenState extends State<SavingDetailScreen> {
  final _amountController = TextEditingController();
  late double _currentAmount;
  bool _isUpdating = false;
  List<Map<String, dynamic>> _movements = [];
  bool _isLoadingMovements = true;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.saving.currentAmount;
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    if (widget.saving.id == null) {
      if (mounted) setState(() => _isLoadingMovements = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('saving_movements')
          .select()
          .eq('saving_id', widget.saving.id!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _movements = List<Map<String, dynamic>>.from(data);
          _isLoadingMovements = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMovements = false);
    }
  }

  Future<void> _updateAmount(bool isAddition) async {
    final text = _amountController.text.trim().replaceAll(',', '.');
    final input = double.tryParse(text);
    
    if (input == null || input <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido mayor a cero'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (widget.saving.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que la meta se guarde en la nube o intenta recargar.'), backgroundColor: Colors.red),
      );
      return;
    }

    final newAmount = isAddition ? _currentAmount + input : _currentAmount - input;
    
    if (newAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes tener ahorros negativos'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await Supabase.instance.client
          .from('savings')
          .update({'current_amount': newAmount})
          .eq('id', widget.saving.id!);

      // Registrar el movimiento en la tabla de historial
      await Supabase.instance.client.from('saving_movements').insert({
        'saving_id': widget.saving.id,
        'amount': input,
        'type': isAddition ? 'deposit' : 'withdrawal',
      });

      setState(() {
        _currentAmount = newAmount;
        _amountController.clear();
      });

      _loadMovements();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Monto actualizado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = widget.saving.targetAmount > 0 
        ? (_currentAmount / widget.saving.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.saving.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Tarjeta de Progreso
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '\$${_currentAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                  ),
                  Text('Ahorrado de \$${widget.saving.targetAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surface,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  Text('${(progress * 100).toInt()}% completado', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Input de Gestión
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto a mover',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            
            if (_isUpdating)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAmount(false),
                      icon: const Icon(Icons.remove),
                      label: const Text('Retirar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAmount(true),
                      icon: const Icon(Icons.add),
                      label: const Text('Ahorrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),

            // Sección de Movimientos
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historial de movimientos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            if (_isLoadingMovements)
              const CircularProgressIndicator()
            else if (_movements.isEmpty)
              const Text('No hay movimientos registrados aún.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final move = _movements[index];
                  final isDeposit = move['type'] == 'deposit';
                  final date = DateTime.parse(move['created_at']).toLocal();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(isDeposit ? Icons.add : Icons.remove, color: isDeposit ? Colors.green : Colors.red),
                    ),
                    title: Text(isDeposit ? 'Depósito' : 'Retiro'),
                    subtitle: Text('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                    trailing: Text(
                      '${isDeposit ? '+' : '-'}\$${(move['amount'] as num).toDouble().toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDeposit ? Colors.green : Colors.red),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}