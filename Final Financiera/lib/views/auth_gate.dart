import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../widgets/santander_loading.dart';
import 'cliente/cliente_shell.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(
        body: SantanderLoading(message: 'Verificando sesión...'),
      );
    }

    if (!auth.isAuthenticated) return const LoginScreen();
    return const ClienteShell();
  }
}
