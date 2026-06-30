import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../viewmodels/notificaciones_viewmodel.dart';
import 'cuentas_screen.dart';
import 'dashboard_screen.dart';
import 'notificaciones_screen.dart';
import 'operaciones_screen.dart';
import 'perfil_screen.dart';

class ClienteShell extends ConsumerStatefulWidget {
  const ClienteShell({super.key});

  @override
  ConsumerState<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends ConsumerState<ClienteShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    CuentasScreen(embedded: true),
    OperacionesScreen(embedded: true),
    NotificacionesScreen(embedded: true),
    PerfilScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final noLeidas = ref.watch(notificacionesProvider).noLeidas;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: BrandColors.red.withValues(alpha: 0.12),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: BrandColors.red),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: BrandColors.red),
            label: 'Cuentas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: BrandColors.red),
            label: 'Operar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: noLeidas > 0,
              label: Text('$noLeidas'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: noLeidas > 0,
              label: Text('$noLeidas'),
              child: const Icon(Icons.notifications, color: BrandColors.red),
            ),
            label: 'Alertas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: BrandColors.red),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
