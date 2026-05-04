import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pagarless/screens/auth_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pagarless/collections/expense.dart';

class OnboardingScreen extends StatefulWidget {
  final Box<Concepto> expenseBox;
  const OnboardingScreen({super.key, required this.expenseBox});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.account_balance_wallet_outlined,
      'title': 'Control Total',
      'desc': 'Gestiona tus gastos diarios y recordatorios en un solo lugar de forma sencilla.',
    },
    {
      'icon': Icons.savings_outlined,
      'title': 'Metas de Ahorro',
      'desc': 'Define objetivos financieros y visualiza tu progreso hacia tus sueños.',
    },
    {
      'icon': Icons.credit_card_outlined,
      'title': 'Billetera Segura',
      'desc': 'Administra tus tarjetas con validación matemática y seguridad avanzada.',
    },
    {
      'icon': Icons.notifications_active_outlined,
      'title': 'Cero Olvidos',
      'desc': 'Configura alertas personalizadas para tus servicios y pagos mensuales.',
    },
    {
      'icon': Icons.lock_person_outlined,
      'title': 'Privacidad Máxima',
      'desc': 'Tus datos están protegidos con acceso mediante PIN y sincronización en la nube.',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AuthScreen(expenseBox: widget.expenseBox)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Saltar'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        // Calculamos la distancia de la página al centro
                        value = (_pageController.page! - index).abs();
                        // Invertimos y limitamos el valor para la opacidad
                        value = (1 - value).clamp(0.0, 1.0);
                      }
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _pages[index]['icon'],
                            size: 120,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 40),
                          Text(
                            _pages[index]['title'],
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _pages[index]['desc'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicadores (Dots)
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                              ? colorScheme.primary 
                              : colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Botón Siguiente / Empezar
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Empezar' : 'Siguiente',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}