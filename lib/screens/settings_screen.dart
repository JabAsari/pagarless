import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pagarless/main.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  late final TextEditingController _nameController;
  String? _avatarUrl;
  bool _isLoading = true;
  String _chartType = 'pie';
  String? _nameError;
  String? _currentPin;
  
  final List<Map<String, dynamic>> _availableColors = [
    {'color': const Color(0xFF2E7D32), 'name': 'Verde Bosque'},
    {'color': const Color(0xFF6750A4), 'name': 'Morado Lavanda'},
    {'color': const Color(0xFF006C51), 'name': 'Esmeralda'},
    {'color': const Color(0xFF3F5AA9), 'name': 'Azul Índigo'},
    {'color': const Color(0xFF9C413D), 'name': 'Rojo Ladrillo'},
    {'color': const Color(0xFF825500), 'name': 'Dorado'},
    {'color': const Color(0xFF006874), 'name': 'Océano'},
    {'color': const Color(0xFF984061), 'name': 'Frambuesa'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfileAndSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Carga los datos del perfil de Supabase y las configuraciones locales.
  Future<void> _loadProfileAndSettings() async {
    final user = _supabase.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();

    if (user != null) {
      _nameController.text = user.userMetadata?['full_name'] ?? '';
      _avatarUrl = user.userMetadata?['avatar_url'];
    }

    _chartType = prefs.getString('chartType') ?? 'pie';
    _currentPin = user?.userMetadata?['user_pin'] as String?; // Cargar PIN desde Supabase

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Muestra un mensaje de éxito al usuario de forma no intrusiva.
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Evita que se acumulen mensajes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 10,
        margin: const EdgeInsets.only(
          bottom: 20,
          left: 20,
          right: 20,
        ),
        dismissDirection: DismissDirection.down,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Muestra un mensaje de error persistente.
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 10,
        margin: const EdgeInsets.only(
          bottom: 20,
          left: 20,
          right: 20,
        ),
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  /// Abre la galería para seleccionar una imagen y la sube a Supabase Storage.
  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final userId = _supabase.auth.currentUser!.id;
      final filePath = '$userId/$fileName';

      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: imageFile.mimeType),
          );

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      await _supabase.auth.updateUser(UserAttributes(
        data: {'avatar_url': imageUrl},
      ));

      if (mounted) {
        setState(() => _avatarUrl = imageUrl);
        _showSuccessMessage('Foto de perfil actualizada con éxito');
      }
    } on StorageException catch (error) {
      _showErrorMessage(error.message);
    } catch (error) {
      _showErrorMessage('Error inesperado');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Actualiza el nombre del usuario.
  Future<void> _updateProfile() async {
    final newName = _nameController.text.trim();

    setState(() => _nameError = null);

    if (newName.isEmpty) {
      setState(() => _nameError = 'El nombre no puede estar vacío');
      return;
    }

    // Validación consistente con el registro
    if (!RegExp(r'^(?=.*[a-zA-ZáéíóúÁÉÍÓÚñÑ])[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s]+$').hasMatch(newName)) {
      setState(() => _nameError = 'Debe contener letras y no ser solo números.');
      return;
    }

    await _supabase.auth.updateUser(UserAttributes(
      data: {'full_name': newName},
    ));
    if (mounted) {
      _showSuccessMessage('Nombre de usuario actualizado con éxito');
      // Devolvemos 'true' para que la pantalla anterior sepa que debe recargar los datos.
      Navigator.pop(context, true);
    }
  }

  /// Cambia el tema de la aplicación y guarda la preferencia.
  Future<void> _changeTheme(ThemeMode? mode) async {
    if (mode == null) return;
    themeNotifier.value = mode; // Actualiza el notificador global
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    _showSuccessMessage('Tema de la aplicación cambiado con éxito');
  }

  /// Cambia el tipo de gráfica y guarda la preferencia.
  Future<void> _changeChartType(String? type) async {
    if (type == null) return;
    setState(() => _chartType = type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chartType', type);
    _showSuccessMessage('Tipo de gráfica actualizado con éxito');
  }

  Future<void> _changeColor(Color color) async {
    colorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.value);
    _showSuccessMessage('Color de acento aplicado con éxito');
  }

  /// Abre un diálogo para configurar o cambiar el PIN.
  Future<void> _showSetPinDialog() async {
    final pinController1 = TextEditingController();
    final pinController2 = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_currentPin == null ? 'Configurar PIN' : 'Cambiar PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController1,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Nuevo PIN (4 dígitos)'),
            ),
            TextField(
              controller: pinController2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Confirmar nuevo PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (pinController1.text.length == 4 && pinController1.text == pinController2.text) {
                // Guardar PIN en Supabase user_metadata
                await _supabase.auth.updateUser(UserAttributes(data: {'user_pin': pinController1.text}));
                setState(() => _currentPin = pinController1.text);
                if (mounted) {
                  Navigator.pop(context);
                  _showSuccessMessage('PIN guardado con éxito');
                }
              } else {
                _showErrorMessage('Los PIN deben coincidir y tener 4 dígitos');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Abre un diálogo para validar el PIN actual y eliminarlo.
  Future<void> _showRemovePinDialog() async {
    final pinController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa tu PIN actual para desactivar la seguridad.'),
            const SizedBox(height: 15),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '****'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (pinController.text == _currentPin) {
                // Eliminar PIN de Supabase user_metadata
                await _supabase.auth.updateUser(UserAttributes(data: {'user_pin': null}));
                setState(() => _currentPin = null);
                if (mounted) {
                  Navigator.pop(context);
                  _showSuccessMessage('PIN eliminado con éxito');
                }
              } else {
                _showErrorMessage('PIN incorrecto');
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Muestra un diálogo para elegir un color personalizado usando sliders RGB
  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = colorNotifier.value;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Color Personalizado'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vista previa del color
                    Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: pickerColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sliders para RGB
                    _buildColorSlider('Rojo', pickerColor.red, Colors.red, (val) {
                      setState(() => pickerColor = Color.fromARGB(255, val, pickerColor.green, pickerColor.blue));
                    }),
                    _buildColorSlider('Verde', pickerColor.green, Colors.green, (val) {
                      setState(() => pickerColor = Color.fromARGB(255, pickerColor.red, val, pickerColor.blue));
                    }),
                    _buildColorSlider('Azul', pickerColor.blue, Colors.blue, (val) {
                      setState(() => pickerColor = Color.fromARGB(255, pickerColor.red, pickerColor.green, val));
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    _changeColor(pickerColor);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorSlider(String label, int value, Color activeColor, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value.toString()),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 255,
          activeColor: activeColor,
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context).brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: BackButton(
          // Al presionar "atrás", también indicamos que se debe recargar.
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              children: [
                // --- SECCIÓN DE PERFIL ---
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null ? const Icon(Icons.person, size: 60) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _uploadAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de usuario',
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Guardar Perfil'),
                ),
                const Divider(height: 40),

                // --- SECCIÓN DE APARIENCIA ---
                Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tema de la aplicación'),
                  trailing: DropdownButton<ThemeMode>(
                    value: currentTheme,
                    items: const [
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                    ],
                    onChanged: _changeTheme,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('Tipo de gráfica de gastos'),
                  trailing: DropdownButton<String>(
                    value: _chartType,
                    items: const [
                      DropdownMenuItem(value: 'pie', child: Text('Pastel')),
                      DropdownMenuItem(value: 'bar', child: Text('Barras')),
                    ],
                    onChanged: _changeChartType,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Color de énfasis', style: Theme.of(context).textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12, // Espacio vertical si se crean nuevas líneas
                    children: [
                      ..._availableColors.map((item) {
                        final color = item['color'] as Color;
                        final name = item['name'] as String;
                        final isSelected = colorNotifier.value.value == color.value;
                        return GestureDetector(
                          onTap: () => _changeColor(color),
                          child: Semantics(
                            label: 'Color $name',
                            selected: isSelected,
                            button: true,
                            child: CircleAvatar(
                              backgroundColor: color,
                              radius: 18,
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _showCustomColorPicker,
                        child: Semantics(
                          label: 'Seleccionar color personalizado',
                          button: true,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            radius: 18,
                            child: const Icon(Icons.colorize, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 40),

                // --- SECCIÓN DE SEGURIDAD ---
                Text('Seguridad', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('PIN de seguridad'),
                  subtitle: Text(_currentPin == null ? 'Desactivado' : 'Activado'),
                  trailing: Switch(
                    value: _currentPin != null,
                    onChanged: (bool value) {
                      if (value) {
                        _showSetPinDialog();
                      } else {
                        _showRemovePinDialog();
                      }
                    },
                  ),
                ),
                if (_currentPin != null)
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Cambiar mi PIN'),
                    onTap: _showSetPinDialog,
                  ),

                const Divider(height: 40),

                // --- SECCIÓN DE CUENTA ---
                Text('Cuenta', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('¿Necesitas ayuda en algo?'),
                  subtitle: const Text('Visita nuestro centro de soporte'),
                  onTap: () async {
                    final url = Uri.parse('https://manualito.vercel.app/');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      _showErrorMessage('No se pudo abrir el centro de soporte');
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade400),
                  title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red.shade400)),
                  onTap: () async {
                    // 1. Cerramos todas las cajas para liberar memoria y archivos
                    await Hive.close();
                    
                    // 2. Eliminamos los datos del disco para aislamiento de usuario
                    await Hive.deleteBoxFromDisk('expenses');
                    
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    await _supabase.auth.signOut();
                    
                    if (mounted) {
                      // 3. Reabrimos la caja (ahora vacía) para pasarla al AuthScreen
                      final newBox = await Hive.openBox<Concepto>('expenses');
                      
                      if (!mounted) return;

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: newBox)),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }
}