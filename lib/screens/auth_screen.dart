import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:pagarless/collections/expense.dart';
import 'package:pagarless/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  final Box<Concepto> expenseBox;
  const AuthScreen({super.key, required this.expenseBox});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Nuevo para el registro
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = false; // Empezar en Registro como en el diseño

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validar nombre si es registro
    if (!_isLogin) {
      if (name.isEmpty) {
        _showError('Por favor, ingresa tu nombre');
        return;
      }
      if (RegExp(r'^[0-9]+$').hasMatch(name)) {
        _showError('El nombre puede tener números, pero no puede ser solo números');
        return;
      }
    }

    // 1. Validar formato de Email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un correo electrónico válido'), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Validar complejidad de contraseña (No permitir solo un tipo de caracter)
    bool hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));

    int typesCount = (hasLetters ? 1 : 0) + (hasNumbers ? 1 : 0) + (hasSpecial ? 1 : 0);

    if (password.length < 6 || typesCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres y ser una mezcla de letras, números o símbolos.'),
          backgroundColor: Colors.red),
      );
      return;
    }

    // Validación básica de contraseñas si es registro
    if (!_isLogin && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(email: email, password: password);
      } else {
        await supabase.auth.signUp(
          email: email, 
          password: password,
          data: {'full_name': name},
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MyHomePage(expenseBox: widget.expenseBox),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tu correo para la verificacion de tu cuenta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡El Email para recuperar tu cuenta fue enviado a tu correo!')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCustomTextField({
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: hint,
      textField: true,
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER VERDE ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, left: 30, right: 30, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Bienvenido de vuelta.' : 'Hola.',
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isLogin ? 'Inicia Sesion' : 'Crea tu cuenta',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENEDOR BLANCO INFERIOR ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white, // Mantenemos blanco para un contraste fuerte en esta pantalla
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        _isLogin ? 'Iniciar Sesión' : 'Resgistrarse',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),

                      // Inputs
                      if (!_isLogin) ...[
                        _buildCustomTextField(
                          hint: 'Ingresa tu nombre completo',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 15),
                      ],
                      _buildCustomTextField(
                        hint: 'Ingresa tu e-mail',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),
                      _buildCustomTextField(
                        hint: 'Ingresa tu Contraseña',
                        controller: _passwordController,
                        isPassword: true,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 15),
                        _buildCustomTextField(
                          hint: 'Confirma tu Contraseña',
                          controller: _confirmPasswordController,
                          isPassword: true,
                        ),
                      ],
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: Text(
                              '¿Olvidaste tu Contraseña?',
                              style: TextStyle(
                                color: colorScheme.primary.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),

                      // Botón Principal
                      if (_isLoading)
                        CircularProgressIndicator(color: colorScheme.primary)
                      else
                        ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                          ),
                          child: Text(
                            _isLogin ? 'Iniciar Sesión' : 'Registrarse',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Toggle Login/Registro
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _emailController.clear();
                            _nameController.clear();
                            _passwordController.clear();
                            _confirmPasswordController.clear();
                          });
                        },
                        child: Text(
                          _isLogin
                              ? '¿No tines una cuenta? Resgistrate'
                              : '¿Ya tienes una cuenta? Inicia Sesión aquí',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}