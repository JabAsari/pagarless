import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pagarless/collections/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpensesTab extends StatefulWidget {
  final Box<Concepto> expenseBox;
  final List<Reminder> reminders;
  final String? userName;

  const ExpensesTab({
    super.key,
    required this.expenseBox,
    this.reminders = const [],
    this.userName,
  });

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  String _chartType = 'pie'; // Valor por defecto

  @override
  void initState() {
    super.initState();
    _loadChartPreference();
  }

  // Carga la preferencia del tipo de gráfica
  Future<void> _loadChartPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _chartType = prefs.getString('chartType') ?? 'pie');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_getGreeting()}, ${widget.userName?.split(' ')[0] ?? "Usuario"}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Contenedor de la Gráfica
        Container(
          height: 200,
          margin: const EdgeInsets.all(16),
          child: ValueListenableBuilder(
            valueListenable: widget.expenseBox.listenable(),
            builder: (context, Box<Concepto> box, __) {
              if (box.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      const Text("Agrega gastos para ver tu gráfica"),
                    ],
                  ),
                );
              }

              // Agrupar gastos por concepto
              final Map<String, double> groupedExpenses = {};
              for (var expense in box.values) {
                final key = expense.title.trim();
                groupedExpenses.update(key, (value) => value + expense.amount, ifAbsent: () => expense.amount);
              }

              final totalValue = groupedExpenses.values.fold(0.0, (sum, item) => sum + item);

              final List<Color> chartColors = [
                Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400,
                Colors.orange.shade400, Colors.purple.shade400, Colors.yellow.shade700,
                Colors.teal.shade400, Colors.pink.shade300
              ];

              // Widget de gráfica
              Widget chartWidget;

              // Renderiza la gráfica según la preferencia del usuario
              if (_chartType == 'bar') {
                // --- GRÁFICA DE BARRAS ---
                int colorIndex = 0;
                final barGroups = groupedExpenses.entries.map((entry) {
                  final color = chartColors[colorIndex % chartColors.length];
                  colorIndex++;
                  return BarChartGroupData(
                    x: colorIndex,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: color,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList();

                chartWidget = BarChart(
                  BarChartData(
                    barGroups: barGroups,
                    alignment: BarChartAlignment.spaceAround,
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  ),
                );
              } else {
                // --- GRÁFICA DE PASTEL (POR DEFECTO) ---
                int colorIndex = 0;
                final sections = groupedExpenses.entries.map((entry) {
                  final percentage = (entry.value / totalValue) * 100;
                  final section = PieChartSectionData(
                    color: chartColors[colorIndex % chartColors.length],
                    value: entry.value,
                    title: percentage > 7 ? '${percentage.toStringAsFixed(0)}%' : '',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  );
                  colorIndex++;
                  return section;
                }).toList();

                chartWidget = PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      // Interactividad futura
                    }),
                  ),
                );
              }

              return Semantics(
                label: "Gráfico de gastos. Total gastado: \$${totalValue.toStringAsFixed(2)}. Tienes ${groupedExpenses.length} categorías de gastos.",
                child: chartWidget,
              );
            },
          ),
        ),
        // Sección de Recordatorios
        if (widget.reminders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recordatorios y Pagos",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120, // Altura fija para la lista horizontal
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = widget.reminders[index];
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 10),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Icono diferente según el tipo
                                Icon(reminder.isRecurring ? Icons.loop : Icons.event, size: 20, color: Theme.of(context).colorScheme.primary),
                                Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                Text('\$${reminder.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                                Text(
                                  reminder.isRecurring ? 'Día ${reminder.dayOfMonth} de cada mes' : 'Fecha: ${reminder.targetDate?.day}/${reminder.targetDate?.month}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: widget.expenseBox.listenable(),
            builder: (context, Box<Concepto> box, __) {
              final sortedExpenses = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

              if (sortedExpenses.isEmpty) return const Center(child: Text('No hay gastos registrados.'));

              return ListView.builder(
                itemCount: sortedExpenses.length,
                itemBuilder: (context, index) {
                  Concepto currentExpense = sortedExpenses[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.attach_money)),
                    title: Text(currentExpense.title),
                    subtitle: Text(currentExpense.date.toLocal().toString().split(' ')[0]),
                    trailing: Text('\$${currentExpense.amount.toStringAsFixed(2)}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}