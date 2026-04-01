import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/carrinho_provider.dart';
import 'welcome_screen.dart';
import 'produtos_screen.dart';
import 'pedidos_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  void _navigate(int i) => setState(() => _idx = i);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final screens = [
      WelcomeScreen(onNavigate: _navigate),
      const ProdutosScreen(),
      const PedidosScreen(),
      const PerfilScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: _idx == 0,
      appBar: AppBar(
        backgroundColor: _idx == 0 ? Colors.transparent : const Color(0xFF0E5A35),
        elevation: 0,
        title: Image.asset(
          _idx == 0
              ? 'assets/images/logo_green_express_full_white.png'
              : 'assets/images/logo_green_express_full_white.png',
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Green Express', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        centerTitle: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.pushNamed(context, '/carrinho'),
              ),
              if (cart.totalItens > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${cart.totalItens}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: screens[_idx],
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: NavigationBar(
            selectedIndex: _idx,
            onDestinationSelected: (i) => setState(() => _idx = i),
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            elevation: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Produtos'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}
