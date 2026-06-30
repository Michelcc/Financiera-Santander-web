import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../core/brand/brand_colors.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/cartera_viewmodel.dart';
import '../widgets/santander_loading.dart';
import '../services/supabase_service.dart';
import 'cartera/cartera_screen.dart';
import 'ruta/ruta_screen.dart';
import 'prospectos/prospectos_screen.dart';
import 'solicitud/estado_solicitudes_screen.dart';
import 'recuperacion/recuperacion_screen.dart';
import 'reportes/reportes_screen.dart';
import 'perfil_screen.dart';
import 'alertas/alertas_screen.dart';
import 'login_screen.dart';

// Group 1: Cartera + Ruta tab shell
class CarteraShell extends StatefulWidget {
  const CarteraShell({super.key});

  @override
  State<CarteraShell> createState() => _CarteraShellState();
}

class _CarteraShellState extends State<CarteraShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent swipe conflict with drag-and-drop
        children: const [
          CarteraScreen(),
          RutaScreen(),
        ],
      ),
      bottomNavigationBar: Material(
        color: BrandColors.red,
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'LISTA DIARIA'),
            Tab(icon: Icon(Icons.map_outlined), text: 'MAPA DE RUTA'),
          ],
        ),
      ),
    );
  }
}

// Group 5: Reportes + Perfil tab shell
class AsesorShell extends StatefulWidget {
  const AsesorShell({super.key});

  @override
  State<AsesorShell> createState() => _AsesorShellState();
}

class _AsesorShellState extends State<AsesorShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: const [
          ReportesScreen(),
          PerfilScreen(),
        ],
      ),
      bottomNavigationBar: Material(
        color: BrandColors.red,
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'MI RENDIMIENTO'),
            Tab(icon: Icon(Icons.person_pin), text: 'MI PERFIL'),
          ],
        ),
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  int _alertasNoLeidas = 0;
  RealtimeChannel? _notifChannel;

  static const _screens = [
    CarteraShell(),
    ProspectosScreen(),
    EstadoSolicitudesScreen(),
    RecuperacionScreen(),
    AsesorShell(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAlertas();
      _notifChannel =
          SupabaseService.instance.subscribeNotificaciones(_refreshAlertas);
    });
  }

  @override
  void dispose() {
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshAlertas() async {
    final role = ref.read(authProvider).role;
    final n = await SupabaseService.instance
        .contarNotificacionesNoLeidas(role: role);
    if (mounted) setState(() => _alertasNoLeidas = n);
  }

  void _openAlertas() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AlertasScreen()))
        .then((_) => _refreshAlertas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: BrandColors.red,
        foregroundColor: Colors.white,
        title: const Text('Santander Fuerza de Ventas'),
        actions: [
          IconButton(
            tooltip: 'Alertas en tiempo real',
            onPressed: _openAlertas,
            icon: Badge(
              isLabelVisible: _alertasNoLeidas > 0,
              label: Text('$_alertasNoLeidas'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        indicatorColor: BrandColors.red.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: BrandColors.red),
            label: 'Cartera',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_outlined),
            selectedIcon: Icon(Icons.person_add, color: BrandColors.red),
            label: 'Prospectos',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in, color: BrandColors.red),
            label: 'Solicitudes',
          ),
          NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on, color: BrandColors.red),
            label: 'Recuperar',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts, color: BrandColors.red),
            label: 'Asesor',
          ),
        ],
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuth = previous?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuth) {
        Future.microtask(() {
          ref.read(carteraProvider.notifier).syncFromServer();
        });
      }
    });

    if (authState.isLoading) {
      return const Scaffold(
        body: SantanderLoading(message: 'Verificando sesión...'),
      );
    }

    if (!authState.isAuthenticated) return const LoginScreen();

    return const AppShell();
  }
}
