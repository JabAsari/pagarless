import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pagarless/screens/home_screen.dart'; 
import 'package:pagarless/collections/expense.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pagarless/screens/auth_screen.dart';

class LoginScreen extends StatefulWidget {
  final Box<Concepto> expenseBox;
  const LoginScreen({super.key, required this.expenseBox});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = "";
  String? _storedPin;
  bool _isLoading = true;
  String _message = "Cargando...";
  final _storage = const FlutterSecureStorage();

  // Mismo color verde oscuro de la pantalla de Auth
  final Color _colorFondoVerde = const Color(0xFF0D704E); 

  @override
  void initState() {
    super.initState();
    _checkIfPinExists();
  }
  
  Future<void> _checkIfPinExists() async {
    final pin = await _storage.read(key: 'user_pin');
    if (!mounted) return;
    setState(() {
      _storedPin = pin;
      _isLoading = false;
      if (pin == null) {
        _message = "Crea un PIN de acceso";
      } else {
        _message = "Ingresa tu PIN";
      }
    });
  }

  void _onKeyPressed(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
      if (_pin.length == 4) {
        _validatePin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (_storedPin == null) {
      await _storage.write(key: 'user_pin', value: _pin);
      _navigateToHome();
    } else {
      if (_pin == _storedPin) {
        _navigateToHome();
      } else {
        setState(() {
          _pin = "";
          _message = "PIN Incorrecto. Intenta de nuevo.";
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MyHomePage(expenseBox: widget.expenseBox)),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recuperar acceso"),
        content: const Text("Si has olvidado tu contraseña o PIN, te enviaremos un correo de verificación para restablecer tu acceso."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              final email = Supabase.instance.client.auth.currentUser?.email;
              if (email != null) {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
              }
              // Borramos el PIN local para permitir una nueva configuración
              await _storage.delete(key: 'user_pin');
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pop(context); // Cierra el diálogo
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: widget.expenseBox)),
                );
              }
            },
            child: const Text("Enviar correo"),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.white.withOpacity(0.2),
            border: isFilled ? null : Border.all(color: Colors.white, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadButton(String value) {
    return InkWell(
      onTap: () => _onKeyPressed(value),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _colorFondoVerde,
        body: const Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }

    return Scaffold(
      backgroundColor: _colorFondoVerde, // Aplicamos el color base aquí
      body: Column(
        children: [
          const Spacer(flex: 2),
          const Icon(
            Icons.lock_outline_rounded,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          Text(
            _message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.white
                ),
          ),
          const SizedBox(height: 40),
          _buildPinDots(),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
              ),
              itemBuilder: (context, index) {
                if (index == 9) return const SizedBox(); 
                if (index == 10) return _buildKeypadButton("0");
                if (index == 11) {
                  return InkWell(
                    onTap: _onDeletePressed,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, color: Colors.white),
                    ),
                  );
                }
                return _buildKeypadButton("${index + 1}");
              },
            ),
          ),
          const Spacer(),
          if (_storedPin == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                "Configuración inicial de seguridad",
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.white.withOpacity(0.8), decoration: TextDecoration.underline, decorationColor: Colors.white.withOpacity(0.8))),
            ),
          ),
        ],
      ),
    );
  }
}