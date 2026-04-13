import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/carrinho_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/carrinho_screen.dart';

/// Chave global do Navigator para redirect de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Garantir que a barra de navegação do sistema não sobreponha o app
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  runApp(const GreenExpressApp());
}

class GreenExpressApp extends StatefulWidget {
  const GreenExpressApp({super.key});
  @override
  State<GreenExpressApp> createState() => _GreenExpressAppState();
}

class _GreenExpressAppState extends State<GreenExpressApp> {
  @override
  void initState() {
    super.initState();

    // Registrar callback global de sessão expirada
    ApiService.onSessionExpired = _onSessionExpired;
  }

  void _onSessionExpired() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Limpar estado de auth
    try {
      final ctx = nav.context;
      ctx.read<AuthProvider>().logout();
    } catch (_) {}

    // Navegar para login e mostrar diálogo
    nav.pushNamedAndRemoveUntil('/login', (route) => false);

    // Mostrar diálogo de sessão expirada após um frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = nav.overlay?.context;
      if (ctx != null) {
        showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            icon: const Icon(Icons.lock_clock, color: Colors.orange, size: 48),
            title: const Text('Sessão Expirada'),
            content: const Text('Sua sessão expirou. Por favor, faça login novamente para continuar.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Entrar novamente'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CarrinhoProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Green Express',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E5A35),
            primary: const Color(0xFF0E5A35),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF0F5F2),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0E5A35),
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E5A35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            color: Colors.white.withValues(alpha: 0.82),
          ),
          navigationBarTheme: NavigationBarThemeData(
            elevation: 0,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            indicatorColor: const Color(0xFF0E5A35).withValues(alpha: 0.14),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (c) => const SplashScreen(),
          '/login': (c) => const LoginScreen(),
          '/home': (c) => const HomeScreen(),
          '/carrinho': (c) => const CarrinhoScreen(),
        },
      ),
    );
  }
}
