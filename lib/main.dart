import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pagarless/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

// Notificador global para que cualquier parte de la app pueda solicitar un cambio de tema.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<Color> colorNotifier = ValueNotifier(const Color(0xFF2E7D32)); // Verde por defecto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  // Cargar las variables de entorno desde el archivo .env
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Inicializar Hive
  await Hive.initFlutter();
  
  // Registrar el adaptador generado
  // Si te marca error aquí, asegúrate de correr: flutter pub run build_runner build
  Hive.registerAdapter(ConceptoAdapter());
  
  // Abrir la caja de gastos antes de iniciar la UI
  final expenseBox = await Hive.openBox<Concepto>('expenses');

  // Cargar la preferencia de tema guardada por el usuario
  final prefs = await SharedPreferences.getInstance();
  final theme = prefs.getString('themeMode') ?? 'system';
  if (theme == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (theme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  }
  
  final colorValue = prefs.getInt('seedColor');
  if (colorValue != null) {
    colorNotifier.value = Color(colorValue);
  }

  runApp(MyApp(expenseBox: expenseBox));
}

class MyApp extends StatelessWidget {
  final Box<Concepto> expenseBox;

  const MyApp({super.key, required this.expenseBox});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder escucha los cambios en themeNotifier y reconstruye
    // MaterialApp con el nuevo tema cuando cambia.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return ValueListenableBuilder<Color>(
          valueListenable: colorNotifier,
          builder: (_, seedColor, __) {
            return MaterialApp(
              title: 'Pagarless',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              // --- TEMA CLARO ---
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'Poppins',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF4F7F5),
                appBarTheme: AppBarTheme(
                  backgroundColor: seedColor,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  elevation: 0,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: seedColor, width: 2),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              // --- TEMA OSCURO ---
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamily: 'Poppins',
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  centerTitle: true,
                ),
              ),
              home: SplashScreen(expenseBox: expenseBox),
            );
          }
        );
      },
    );
  }
}
