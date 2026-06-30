import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/brand/brand_colors.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/premium_card.dart';
import '../widgets/santander_icon.dart';
import '../widgets/santander_logo.dart';
import 'registro_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _docController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          _docController.text.trim(),
          _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5F5), BrandColors.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 6,
                decoration: const BoxDecoration(
                  gradient: BrandColors.headerGradient,
                ),
              ),
              const SizedBox(height: 32),
              const SantanderLogo(height: 44, animate: true),
              const SizedBox(height: 10),
              const Text(
                'CONSUMER • PORTAL DE CLIENTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: BrandColors.muted,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedEntrance(
                          index: 1,
                          child: PremiumCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Bienvenido',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: BrandColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Ingresa solo tu DNI (8 dígitos)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: BrandColors.muted,
                                  ),
                                ),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: BrandColors.darkRed
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: BrandColors.darkRed,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            auth.error!,
                                            style: const TextStyle(
                                              color: BrandColors.darkRed,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _docController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'DNI',
                                    hintText: 'Ej: 45781290',
                                    helperText:
                                        'No ingrese el correo; solo el número de DNI',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Ingrese su DNI'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Ingrese su contraseña'
                                      : null,
                                ),
                                const SizedBox(height: 28),
                                ElevatedButton(
                                  onPressed: auth.isLoading ? null : _submit,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: SantanderIcon(
                                            size: 24,
                                            pulse: true,
                                          ),
                                        )
                                      : const Text('INGRESAR'),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                            const RegistroScreen(),
                                        transitionsBuilder:
                                            (_, animation, __, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.05),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    child: const Text(
                                      '¿Eres nuevo? Regístrate aquí',
                                      style: TextStyle(
                                        color: BrandColors.red,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const AnimatedEntrance(
                          index: 3,
                          child: Text(
                            '© 2026 Santander Consumer Perú S.A.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: BrandColors.muted),
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
    );
  }
}
