import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/carrinho_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();
    _init();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await context.read<CarrinhoProvider>().loadCarrinho();
    await context.read<AuthProvider>().checkAuthStatus();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final isAuth = context.read<AuthProvider>().isAuthenticated;

    // SEMPRE vai para login se não estiver autenticado (token expirado = não autenticado)
    Navigator.of(context).pushReplacementNamed(isAuth ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Padding bottom para barra de navegação do sistema
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.only(bottom: bottomPad),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B4D2C), Color(0xFF0E5A35), Color(0xFF14733F)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Image.asset(
                        'assets/images/logo_green_express_full_white.png',
                        width: 280,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 80, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
