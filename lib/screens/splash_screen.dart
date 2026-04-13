import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/auth_screen.dart';
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => session != null
            ? MyHomePage(expenseBox: widget.expenseBox)
            : AuthScreen(expenseBox: widget.expenseBox),
      ),
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
            const Icon(Icons.account_balance_wallet, size: 100, color: Colors.white),
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