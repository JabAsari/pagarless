import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:pagarless/screens/home_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final String correctPin;
  final Box<Concepto> expenseBox;

  const PinVerificationScreen({
    super.key,
    required this.correctPin,
    required this.expenseBox,
  });

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  String? _pinError;

  void _verifyPin() {
    setState(() {
      _pinError = null;
    });

    if (_pinController.text == widget.correctPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MyHomePage(expenseBox: widget.expenseBox),
        ),
      );
    } else {
      setState(() {
        _pinError = 'PIN incorrecto. Inténtalo de nuevo.';
      });
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Verificación de PIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ingresa tu PIN de seguridad para acceder a la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _pinFocusNode.requestFocus(),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Campo oculto que captura la entrada del teclado
                              Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _pinController,
                                  focusNode: _pinFocusNode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  autofocus: true,
                                  onChanged: (value) {
                                    setState(() {}); // Reconstruye para actualizar los cuadros
                                    if (value.length == 4) {
                                      _verifyPin();
                                    }
                                  },
                                ),
                              ),
                              // Interfaz visual de cuadros para el PIN
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(4, (index) {
                                  final isFilled = _pinController.text.length > index;
                                  final isFocused = _pinController.text.length == index;
                                  return Container(
                                    width: 50,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isFocused ? colorScheme.primary : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: isFilled
                                        ? Icon(Icons.circle, size: 16, color: colorScheme.primary)
                                        : null,
                                  );
                                }),
                              ),
                            ],
                          ),
                          if (_pinError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _pinError!,
                              style: TextStyle(color: colorScheme.error, fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _verifyPin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                      ),
                      child: const Text(
                        'Acceder',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        // If user cancels, they should go back to AuthScreen
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => AuthScreen(expenseBox: widget.expenseBox),
                          ),
                        );
                      },
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: colorScheme.primary.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}