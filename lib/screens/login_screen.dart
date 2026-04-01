import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _senhaC = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _emailC.dispose(); _senhaC.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailC.text.trim(), _senhaC.text);
    if (!mounted) return;
    if (ok) { Navigator.of(context).pushReplacementNamed('/home'); return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(auth.errorMessage ?? 'Falha ao entrar'),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B4D2C), Color(0xFF0E5A35), Color(0xFF14733F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Image.asset(
                          'assets/images/logo_green_express_full_white.png',
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 60, color: Colors.white),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              children: [
                                Text('Acesse sua conta', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 17, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _emailC,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDec('Email', Icons.email_outlined),
                                  validator: (v) => v == null || !v.contains('@') ? 'Email invalido' : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _senhaC,
                                  obscureText: _obscure,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDec('Senha', Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.length < 4 ? 'Senha invalida' : null,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                        : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
      prefixIcon: Icon(icon, color: Colors.white70),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
    );
  }
}
