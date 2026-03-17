import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:pagarless/screens/login_screen.dart';

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
    _redirect();
  }

  Future<void> _redirect() async {
    // Espera un frame para asegurar que el widget está montado y
    // para darle tiempo a Supabase de restaurar la sesión.
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen(expenseBox: widget.expenseBox)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: widget.expenseBox)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}