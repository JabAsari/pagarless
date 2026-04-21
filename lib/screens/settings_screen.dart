import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pagarless/main.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
      }
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error inesperado'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Actualiza el nombre del usuario.
  Future<void> _updateProfile() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validar que no sean solo números
    if (RegExp(r'^[0-9]+$').hasMatch(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre puede contener números, pero no puede ser solo números'), backgroundColor: Colors.red),
      );
      return;
    }

    await _supabase.auth.updateUser(UserAttributes(
      data: {'full_name': newName},
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
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
  }

  /// Cambia el tipo de gráfica y guarda la preferencia.
  Future<void> _changeChartType(String? type) async {
    if (type == null) return;
    setState(() => _chartType = type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chartType', type);
  }

  Future<void> _changeColor(Color color) async {
    colorNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.value);
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
                  decoration: const InputDecoration(labelText: 'Nombre de usuario'),
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

                // --- SECCIÓN DE CUENTA ---
                Text('Cuenta', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade400),
                  title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red.shade400)),
                  onTap: () async {
                    // Limpiamos los datos locales (Hive) para que el siguiente usuario
                    // no vea la información financiera del usuario anterior.
                    final expenseBox = Hive.box<Concepto>('expenses');
                    await expenseBox.clear();

                    await _supabase.auth.signOut();
                    if (mounted) {
                      // Usamos pushAndRemoveUntil para limpiar el historial de navegación
                      // y evitar que el usuario pueda volver a la app con el botón de atrás.
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: expenseBox)),
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