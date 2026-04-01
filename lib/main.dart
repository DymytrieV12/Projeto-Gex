import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/carrinho_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/carrinho_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GreenExpressApp());
}

class GreenExpressApp extends StatelessWidget {
  const GreenExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CarrinhoProvider()),
      ],
      child: MaterialApp(
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
