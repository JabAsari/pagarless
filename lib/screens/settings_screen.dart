import 'dart:io';
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
  
  final List<Color> _availableColors = [
    const Color(0xFF2E7D32), // Verde (Default)
    const Color(0xFF1976D2), // Azul
    const Color(0xFFD32F2F), // Rojo
    const Color(0xFF7B1FA2), // Morado
    const Color(0xFFF57C00), // Naranja
    const Color(0xFF00796B), // Teal
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
                    children: _availableColors.map((color) {
                      return GestureDetector(
                        onTap: () => _changeColor(color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 18,
                          child: colorNotifier.value.value == color.value
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
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
                    await _supabase.auth.signOut();
                    if (mounted) {
                      // Usamos pushAndRemoveUntil para limpiar el historial de navegación
                      // y evitar que el usuario pueda volver a la app con el botón de atrás.
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: Hive.box<Concepto>('expenses'))),
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