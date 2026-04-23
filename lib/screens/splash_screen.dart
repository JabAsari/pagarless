import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:pagarless/screens/pin_verification_screen.dart';
import 'package:pagarless/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  final Box<Concepto> expenseBox;
  const SplashScreen({super.key, required this.expenseBox});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Damos un tiempo de 3 segundos para que se aprecie la pantalla de carga
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Verificamos si hay una sesión activa en Supabase
    final session = Supabase.instance.client.auth.currentSession;

    Widget nextScreen;
    if (session != null) {
      final userPin = session.user.userMetadata?['user_pin'] as String?;
      if (userPin != null && userPin.isNotEmpty) {
        nextScreen = PinVerificationScreen(correctPin: userPin, expenseBox: widget.expenseBox);
      } else {
        nextScreen = MyHomePage(expenseBox: widget.expenseBox);
      }
    } else {
      nextScreen = AuthScreen(expenseBox: widget.expenseBox);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Usamos el color primario del tema para el fondo
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o Icono de la App
            Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0,10))]),
              child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            // Nombre de la App
            const Text(
              'Pagarless',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Nombre del Autor (basado en tu ruta de usuario)
            const Text(
              'By Jaime Asarías Sánchez Pérez',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 60),
            // Indicador de carga
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}