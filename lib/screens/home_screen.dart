import 'package:flutter/material.dart' hide Card; // Ocultamos el widget Card para evitar conflicto con tu modelo
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/settings_screen.dart';
import 'package:pagarless/collections/saving.dart';
import 'package:pagarless/collections/card.dart';
import 'package:pagarless/collections/reminder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pagarless/screens/expenses_tab.dart';
import 'package:pagarless/screens/savings_tab.dart';
import 'package:pagarless/screens/wallet_tab.dart';
import 'package:pagarless/screens/saving_detail_screen.dart';
import 'package:pagarless/screens/notifications_tab.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

class MyHomePage extends StatefulWidget {
  final Box<Concepto> expenseBox;
  const MyHomePage({super.key, required this.expenseBox});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late PageController _pageController;
  int _selectedIndex = 0;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Usamos los nuevos modelos para tener un código más seguro y limpio
  final List<Saving> _savings = [];
  final List<Card> _cards = [];
  final List<Reminder> _reminders = [];
  final List<Map<String, dynamic>> _notificationsHistory = [];
  // Variables para datos del perfil
  String? _userName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _initNotifications();
    _loadSupabaseData();
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) {
      debugPrint('Notificaciones locales en Web: Se usará fallback de SnackBar.');
      return;
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _testLocalNotification(String title, String body, {DateTime? scheduledDate}) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('[$title] $body')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Recordatorios',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    if (scheduledDate != null) {
      await _notificationsPlugin.zonedSchedule(
        DateTime.now().millisecond,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      await _notificationsPlugin.show(0, title, body, details);
    }
  }

  /// Algoritmo de Luhn para verificar si una tarjeta es matemáticamente válida
  bool _isLuhnValid(String cardNumber) {
    cardNumber = cardNumber.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    int sum = 0;
    bool alternate = false;
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int n = int.parse(cardNumber[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Elimina una tarjeta tanto de Supabase como del estado local
  Future<void> _deleteCard(Card card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarjeta'),
        content: Text('¿Estás seguro de que deseas eliminar "${card.alias}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          await Supabase.instance.client.from('cards').delete().eq('user_id', userId).eq('last_4_digits', card.last4Digits);
          setState(() {
            _cards.removeWhere((c) => c.number == card.number);
          });
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSupabaseData() async {
    // --- CORRECCIÓN DE SEGURIDAD: Limpiar estados inmediatamente ---
    // Esto evita que al cambiar de usuario se vea la info del anterior durante la carga.
    if (mounted) {
      setState(() {
        _savings.clear();
        _cards.clear();
        _reminders.clear();
        _notificationsHistory.clear();
      });
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    // Cargar datos del perfil del usuario
    _userName = user.userMetadata?['full_name'];
    _avatarUrl = user.userMetadata?['avatar_url'];
    final userId = user.id;

    try {
      // Cargar Ahorros y Tarjetas desde la nube
      final savingsData = await supabase.from('savings').select().eq('user_id', userId);
      final cardsData = await supabase.from('cards').select().eq('user_id', userId);
      final List<dynamic> rawReminders = await supabase.from('reminders').select().eq('user_id', userId);

      // --- LÓGICA DE LIMPIEZA Y MIGRACIÓN ---
      final now = DateTime.now();
      final List<Map<String, dynamic>> activeRemindersData = [];

      for (var reminder in rawReminders) {
        final map = reminder as Map<String, dynamic>;
        final isRecurring = map['is_recurring'] as bool? ?? false;
        bool moved = false;

        if (!isRecurring && map['target_date'] != null) {
          final targetDate = DateTime.parse(map['target_date']);
          // Si la fecha ya pasó (ayer o antes)
          if (targetDate.isBefore(now)) {
            // 1. Mover al historial
            await supabase.from('notifications_history').insert({
              'user_id': userId,
              'title': map['title'],
              'amount': map['amount'],
              'original_date': map['target_date'],
            });
            // 2. Eliminar de recordatorios activos
            await supabase.from('reminders').delete().eq('id', map['id']);
            moved = true;
          }
        }
        if (!moved) activeRemindersData.add(map);
      }

      // Cargar el historial actualizado
      final historyData = await supabase
          .from('notifications_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Sincronización de Gastos:
      // Si no tenemos gastos locales (ej. instalación nueva), intentamos bajarlos de la nube.
      if (widget.expenseBox.isEmpty) {
        final expensesData = await supabase.from('expenses').select().eq('user_id', userId);
        for (var item in expensesData) {
          final expense = Concepto(
            title: item['title'] ?? 'Sin título', // Protección contra nulos
            amount: (item['amount'] as num?)?.toDouble() ?? 0.0, // Protección contra nulos
            date: DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now(), // Protección contra fechas inválidas
          );
          await widget.expenseBox.add(expense);
        }
      }

      if (mounted) {
        setState(() {
          _savings.addAll(savingsData.map((item) => Saving.fromMap(item as Map<String, dynamic>)));
          _cards.addAll(cardsData.map((item) => Card.fromMap(item as Map<String, dynamic>)));
          _reminders.addAll(activeRemindersData.map((item) => Reminder.fromMap(item)));
          _notificationsHistory.addAll(List<Map<String, dynamic>>.from(historyData));
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de Supabase: $e');
    }
  }

  void _onFabPressed() {
    switch (_selectedIndex) {
      case 0:
        _showAddExpenseModal();
        break;
      case 1:
        _showAddSavingsModal();
        break;
      case 2:
        _showAddCardModal();
        break;
    }
  }

  void _showAddExpenseModal({String? initialTitle}) {
    final titleController = TextEditingController(text: initialTitle);
    final amountController = TextEditingController();
    final dayController = TextEditingController(); // Para día del mes (1-31)
    
    // 0 = Gasto Ya Realizado
    // 1 = Recordatorio Pago Único (Fiesta, Cooperación)
    // 2 = Servicio Mensual (Netflix, Luz)
    int selectedType = 0; 
    DateTime? selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    int leadTimeMinutes = 0; // 0 = Al momento, 15, 60, 1440

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Agregar Movimiento", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                
                // Selector de Tipo
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Gasto'), icon: Icon(Icons.money_off)),
                    ButtonSegment(value: 1, label: Text('Recordatorio'), icon: Icon(Icons.event)),
                    ButtonSegment(value: 2, label: Text('Mensual'), icon: Icon(Icons.loop)),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (Set<int> newSelection) {
                    setModalState(() {
                      selectedType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: selectedType == 0 ? "Concepto" : "Título del recordatorio",
                    prefixIcon: const Icon(Icons.description_outlined)
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: "Monto", prefixIcon: Icon(Icons.attach_money)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
                
                // Campo condicional: Fecha (para Recordatorio Único)
                if (selectedType == 1) ...[
                  const SizedBox(height: 15),
                  ListTile(
                    title: Text(selectedDate == null ? "Seleccionar Fecha" : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
                    leading: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],

                // Configuración de la hora (Visible para cualquier recordatorio)
                if (selectedType != 0) ...[
                  const SizedBox(height: 15),
                  ListTile(
                    title: Text("Hora de notificación: ${selectedTime.format(context)}"),
                    leading: const Icon(Icons.access_time),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                  ),
                ],

                // Nuevo selector de Antelación (Solo para recordatorios)
                if (selectedType != 0) ...[
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: leadTimeMinutes,
                    decoration: const InputDecoration(
                      labelText: "Avisarme antes",
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('En el momento')),
                      DropdownMenuItem(value: 15, child: Text('15 minutos antes')),
                      DropdownMenuItem(value: 60, child: Text('1 hora antes')),
                      DropdownMenuItem(value: 1440, child: Text('1 día antes')),
                    ],
                    onChanged: (val) => setModalState(() => leadTimeMinutes = val!),
                  ),
                ],

                // Campo condicional: Día del mes (para Servicio Mensual)
                if (selectedType == 2) ...[
                  const SizedBox(height: 15),
                  TextField(
                    controller: dayController,
                    decoration: const InputDecoration(labelText: "Día de pago (1-31)", prefixIcon: Icon(Icons.calendar_view_day)),
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                  ),
                ],

                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amountText = amountController.text.trim().replaceAll(',', '.');
                    final amount = double.tryParse(amountText);
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    
                    // Capturamos variables locales para asegurar promoción de tipos y validez del context
                    final dateToProcess = selectedDate;
                    final timeLabel = selectedTime.format(context);

                    if (title.isNotEmpty && amount != null && userId != null) {
                      // Validar que el concepto sea exclusivamente letras
                      if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(title)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El concepto solo debe contener letras.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // Validar que el monto no sobrepase los 10 dígitos
                      if (amountText.replaceAll('.', '').length > 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El monto no puede superar los 10 dígitos.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      Navigator.pop(context); // Cerrar modal primero

                      if (selectedType == 0) {
                        // --- CASO 1: GASTO NORMAL ---
                        final now = DateTime.now();
                        final newExpense = Concepto(title: title, amount: amount, date: now);
                        
                        try {
                          await Supabase.instance.client.from('expenses').insert({
                            'user_id': userId,
                            'title': title,
                            'amount': amount,
                            'date': now.toIso8601String(),
                          });
                          widget.expenseBox.add(newExpense); // Solo guardamos en Hive si Supabase acepta (o manejar modo offline)
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al guardar gasto: $e'), backgroundColor: Colors.red),
                            );
                          }
                          return; // Salimos para no cerrar el modal si falló
                        }
                      } else {
                        // --- CASO 2 y 3: RECORDATORIOS ---
                        final isRecurring = selectedType == 2;
                        final dayOfMonth = int.tryParse(dayController.text);
                        
                        // Validaciones extra con variables locales seguras
                        if (isRecurring && (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31)) return;
                        if (!isRecurring && dateToProcess == null) return;

                        // Combinamos fecha y hora para recordatorios puntuales
                        final DateTime finalDateTime = !isRecurring 
                          ? DateTime(
                              dateToProcess!.year, 
                              dateToProcess.month, 
                              dateToProcess.day, 
                              selectedTime.hour, 
                              selectedTime.minute
                            )
                          : DateTime.now();

                        try {
                          await Supabase.instance.client.from('reminders').insert({
                            'user_id': userId,
                            'title': title,
                            'amount': amount,
                            'is_recurring': isRecurring,
                            'day_of_month': isRecurring ? dayOfMonth : null,
                            'target_date': !isRecurring ? finalDateTime.toIso8601String() : null,
                            'reminder_time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al crear recordatorio: $e'), backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }
                        
                        // 1. Programamos la notificación real para el futuro con los detalles del recordatorio
                        if (!isRecurring) {
                          // Restamos la antelación seleccionada
                          final scheduledNotificationDate = finalDateTime.subtract(Duration(minutes: leadTimeMinutes));
                          
                          _testLocalNotification(
                            'Pagar $title', 
                            'Recordatorio: Tienes un pago pendiente de \$${amount.toStringAsFixed(2)}' + 
                            (leadTimeMinutes > 0 ? ' (En ${leadTimeMinutes >= 60 ? leadTimeMinutes~/60 : leadTimeMinutes} ${leadTimeMinutes >= 60 ? "hora/s" : "minutos"})' : ''), 
                            scheduledDate: scheduledNotificationDate.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(seconds: 5)) : scheduledNotificationDate
                          );
                        }

                        // 2. Notificación inmediata de confirmación para el usuario
                        _testLocalNotification('Pagarless', 'Recordatorio para "$title" guardado correctamente.');

                        // Recargar datos para ver el nuevo recordatorio
                        _loadSupabaseData();
                      }
                    }
                  },
                  child: Text(selectedType == 0 ? "Registrar Gasto" : "Crear Recordatorio"),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showAddSavingsModal() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Nueva Meta", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(labelText: "Nombre de la meta", prefixIcon: Icon(Icons.flag)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: targetController, 
              decoration: const InputDecoration(labelText: "Monto objetivo", prefixIcon: Icon(Icons.savings)), 
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final amountText = targetController.text.trim().replaceAll(',', '.');
                final amount = double.tryParse(amountText);

                if (name.isNotEmpty && amount != null) {
                  // Validar que el nombre de la meta sea exclusivamente letras
                  if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(name)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre de la meta solo debe contener letras.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  // Validar que el monto no sobrepase los 10 dígitos (Contando solo números)
                  final digitCount = amountText.replaceAll(RegExp(r'[^0-9]'), '').length;
                  if (digitCount > 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El monto no puede superar los 10 dígitos.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final newSaving = Saving(name: name, targetAmount: amount, createdAt: DateTime.now());

                  // 1. Actualiza la UI inmediatamente (Optimistic Update)
                  setState(() {
                    _savings.add(newSaving);
                  });
                  Navigator.pop(context);

                  // 2. Intenta guardar en la base de datos
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId != null) {
                    try {
                      final response = await Supabase.instance.client.from('savings').insert({
                        'user_id': userId,
                        'name': newSaving.name,
                        'target_amount': newSaving.targetAmount,
                      }).select().single();
                      
                      // Actualizamos el ID local con el generado por la base de datos
                      if (mounted) {
                        setState(() {
                          final index = _savings.indexOf(newSaving);
                          if (index != -1) _savings[index] = Saving.fromMap(response);
                        });
                      }
                    } catch (e) {
                      // 3. Si falla, revierte el cambio y muestra un error
                      setState(() {
                        _savings.remove(newSaving);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.red));
                      }
                    }
                  }
                }
              },
              child: const Text("Crear Meta"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardModal() {
    final aliasController = TextEditingController();
    final numberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvcController = TextEditingController();
    String detectedNetwork = "Desconocida";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Agregar Tarjeta", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(labelText: "Alias (Ej. Nómina)", prefixIcon: Icon(Icons.label_outline)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
                  ],
                ),
                const SizedBox(height: 15),
                
                // Campo de Número de Tarjeta con detección
                TextField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: "Número de Tarjeta", 
                    prefixIcon: const Icon(Icons.credit_card),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(detectedNetwork, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    )
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  onChanged: (value) {
                    setModalState(() {
                      if (value.startsWith('4')) {
                        detectedNetwork = 'VISA';
                      } else if (value.startsWith('5')) {
                        detectedNetwork = 'MASTERCARD';
                      } else {
                        detectedNetwork = 'OTRA';
                      }
                    });
                  },
                ),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryController,
                        decoration: const InputDecoration(labelText: "Vigencia (MM/AA)", prefixIcon: Icon(Icons.calendar_today), hintText: "MM/AA"),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _CardExpiryInputFormatter(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: cvcController,
                        decoration: const InputDecoration(labelText: "CVC", prefixIcon: Icon(Icons.lock_outline)),
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () async {
                    final alias = aliasController.text.trim();
                    final number = numberController.text.trim();
                    final expiry = expiryController.text.trim();
                    final cvc = cvcController.text.trim();

                    // Validar existencia matemática de la tarjeta
                    if (!_isLuhnValid(number)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El número de tarjeta no es válido (Fallo de verificación bancaria)'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    if (alias.isNotEmpty && number.length >= 13 && expiry.isNotEmpty && cvc.length == 3) {
                      final last4 = number.substring(number.length - 4);
                      
                      final newCard = Card(
                        alias: alias, 
                        last4Digits: last4, 
                        number: number,
                        expiryDate: expiry,
                        cvc: cvc,
                        network: detectedNetwork,
                        createdAt: DateTime.now()
                      );

                      // 1. Actualización optimista de la UI
                      setState(() {
                        _cards.add(newCard);
                      });
                      Navigator.pop(context);

                      // 2. Intenta guardar en Supabase
                      final userId = Supabase.instance.client.auth.currentUser?.id;
                      if (userId != null) {
                        try {
                          await Supabase.instance.client.from('cards').insert({
                            'user_id': userId,
                            'alias': newCard.alias,
                            'last_4_digits': newCard.last4Digits,
                            'expiry_date': newCard.expiryDate,
                            'network': newCard.network,
                          });
                        } catch (e) {
                          // 3. Si falla, revierte el cambio y notifica
                          setState(() {
                            _cards.remove(newCard);
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.red));
                          }
                        }
                      }
                    }
                  },
                  child: const Text("Guardar Tarjeta"),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ExpensesTab(
        expenseBox: widget.expenseBox, 
        reminders: _reminders,
        userName: _userName,
      ),
      SavingsTab(
        savings: _savings,
        onSavingTapped: (saving) async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SavingDetailScreen(saving: saving),
            ),
          );
          _loadSupabaseData(); // Recarga los datos cuando el usuario regresa
        },
      ),
      WalletTab(
        cards: _cards,
        onCardTapped: (card) {
          _showAddExpenseModal(initialTitle: 'Gasto con ${card.alias}');
        },
        onDeleteCard: _deleteCard,
      ),
      NotificationsTab(history: _notificationsHistory),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagarless'),
        actions: [
          if (_avatarUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(_avatarUrl!),
                radius: 18,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notification_important),
            tooltip: 'Modo Desarrollador: Probar Notificación',
            onPressed: () {
              _testLocalNotification('Test de Sistema', 'Verificación de que el servicio de alertas está activo.');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // Navegamos a la pantalla de configuración y esperamos a que vuelva.
              // Si devuelve 'true', significa que el perfil se actualizó y debemos recargar.
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen())
              );

              if (result == true && mounted) {
                _loadSupabaseData(); // Recarga los datos del perfil
              }
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: pages,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface, // Usa el color de superficie del tema
            borderRadius: BorderRadius.circular(20), // Bordes redondeados
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15), // Sombra para el efecto flotante
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent, // Fondo transparente para que se vea el Container
            elevation: 0, // Elimina la elevación por defecto de NavigationBar
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Gastos',
              ),
              NavigationDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings),
                label: 'Ahorros',
              ),
              NavigationDestination(
                icon: Icon(Icons.wallet_outlined),
                selectedIcon: Icon(Icons.wallet),
                label: 'Wallet',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Inbox',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 3 ? null : FloatingActionButton(
        onPressed: _onFabPressed,
        child: Icon(_selectedIndex == 2 ? Icons.add_card : Icons.add),
      ),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }
    
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}