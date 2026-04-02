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
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  int _notifCount = 2; // Simulated unread notification count

  void _navigate(int i) => setState(() => _idx = i);

  final List<_NotifItem> _notifications = [
    _NotifItem(
      icon: Icons.local_offer,
      title: 'Promocao Especial!',
      body: 'Kit Divulgacao com 30% de desconto. Valido ate o fim do mes!',
      time: 'Hoje',
      color: Colors.orange,
    ),
    _NotifItem(
      icon: Icons.local_shipping,
      title: 'Pedido #19106 Recebido',
      body: 'Seu pedido foi recebido e esta sendo processado.',
      time: 'Ontem',
      color: Colors.blue,
    ),
    _NotifItem(
      icon: Icons.new_releases,
      title: 'Novo produto disponivel',
      body: 'Afrodite esta de volta ao estoque! Garanta o seu.',
      time: '2 dias atras',
      color: Colors.green,
    ),
  ];

  void _showNotifications() {
    setState(() => _notifCount = 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, sc) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: 0.92), Colors.white.withValues(alpha: 0.82)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  child: SingleChildScrollView(
                    controller: sc,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 42, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999)))),
                        const Row(
                          children: [
                            Icon(Icons.notifications_rounded, color: Color(0xFF0E5A35), size: 24),
                            SizedBox(width: 8),
                            Text('Notificacoes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._notifications.map((n) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: n.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                child: Icon(n.icon, color: n.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                        Text(n.time, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.body, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (_notifications.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(children: [
                                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text('Nenhuma notificacao', style: TextStyle(color: Colors.grey[500])),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
          'assets/images/logo_green_express_full_white.png',
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Green Express', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        centerTitle: false,
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _showNotifications,
              ),
              if (_notifCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_notifCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          // Cart icon
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

class _NotifItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final Color color;
  const _NotifItem({required this.icon, required this.title, required this.body, required this.time, required this.color});
}
