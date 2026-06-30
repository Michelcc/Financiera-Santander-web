import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/brand/brand_colors.dart';
import '../models/auth_status.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/premium_card.dart';
import '../widgets/santander_icon.dart';
import '../widgets/santander_logo.dart';

const _roles = [
  'Operador',
  'Super Operador',
  'Supervisor',
  'Administrador',
];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = _roles.first;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          _codeController.text.trim(),
          _passwordController.text.trim(),
          _selectedRole,
        );

    if (!success && mounted) {
      final errorMsg =
          ref.read(authProvider).error ?? 'Credenciales inválidas.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: BrandColors.darkRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
                'CONSUMER • FUERZA DE VENTAS',
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
                                  'Iniciar Sesión',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: BrandColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Acceso para asesores de negocio',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: BrandColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (authState.status == AuthStatus.bloqueado &&
                                    authState.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      authState.error!,
                                      style: const TextStyle(
                                        color: BrandColors.darkRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                TextFormField(
                                  controller: _codeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Código de asesor',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingrese su código de asesor';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingrese su contraseña';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Perfil',
                                    prefixIcon: Icon(Icons.shield_outlined),
                                  ),
                                  items: _roles
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: authState.isLoading
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(
                                                () => _selectedRole = value);
                                          }
                                        },
                                ),
                                const SizedBox(height: 28),
                                ElevatedButton(
                                  onPressed:
                                      authState.isLoading ? null : _submit,
                                  child: authState.isLoading
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const AnimatedEntrance(
                          index: 3,
                          child: Text(
                            'Sesión persistente • Modo offline disponible',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: BrandColors.muted),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const AnimatedEntrance(
                          index: 4,
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
