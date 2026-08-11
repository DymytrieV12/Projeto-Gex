import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/carrinho_provider.dart';
import '../services/notification_service.dart';
import 'welcome_screen.dart';
import 'produtos_screen.dart';
import 'pedidos_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  bool _notifBootstrapped = false;

  void _navigate(int i) => setState(() => _idx = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notifBootstrapped) {
      _notifBootstrapped = true;
      Future.microtask(() => context.read<NotificationService>().init());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationService>().syncNow();
    }
  }

  void _showNotifications(NotificationService notif) {
    notif.markAllRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.40,
          maxChildSize: 0.88,
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
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        Colors.white.withValues(alpha: 0.82),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  child: SingleChildScrollView(
                    controller: sc,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(ctx).padding.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_rounded,
                              color: Color(0xFF0E5A35),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Notificações',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: notif.items.isEmpty
                                  ? null
                                  : () async {
                                      await notif.clear();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (mounted) _showNotifications(notif);
                                    },
                              icon: const Icon(Icons.delete_sweep_rounded),
                              label: const Text('Limpar tudo'),
                            ),
                            IconButton(
                              tooltip: 'Atualizar agora',
                              onPressed: () async {
                                await notif.syncNow();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) _showNotifications(notif);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'O app consulta a API a cada 20 minutos e gera notificações nativas quando o status do pedido muda.',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                        ),
                        const SizedBox(height: 16),
                        if (notif.items.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nenhuma notificação',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...notif.items.map(
                            (n) => InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _idx = 2);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _notifColor(n.type, n.body)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _notifIcon(n.type, n.body),
                                        color: _notifColor(n.type, n.body),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n.body,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _relativeTime(n.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _notifIcon(String type, String body) {
    final lower = body.toLowerCase();
    if (type == 'status') {
      if (lower.contains('entreg')) return Icons.check_circle_rounded;
      if (lower.contains('cancel')) return Icons.cancel_rounded;
      if (lower.contains('envi')) return Icons.local_shipping_rounded;
      return Icons.receipt_long_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _notifColor(String type, String body) {
    final lower = body.toLowerCase();
    if (type == 'status') {
      if (lower.contains('entreg')) return Colors.green;
      if (lower.contains('cancel')) return Colors.red;
      if (lower.contains('envi')) return Colors.blue;
      return Colors.orange;
    }
    return const Color(0xFF0E5A35);
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final notif = context.watch<NotificationService>();

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
          errorBuilder: (_, __, ___) => const Text(
            'Green Express',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotifications(notif),
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notif.unreadCount > 9 ? '9+' : '${notif.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.pushNamed(context, '/carrinho'),
              ),
              if (cart.totalItens > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.totalItens}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: screens[_idx],
      bottomNavigationBar: SafeArea(
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: NavigationBar(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _idx = i),
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Produtos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Pedidos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
