import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/sync_service.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  int _pendingSyncCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkPendingSync();
  }

  Future<void> _checkPendingSync() async {
    final count = await SyncService.instance.getPendingSyncCount();
    if (mounted) {
      setState(() {
        _pendingSyncCount = count;
      });
    }
  }

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    await SyncService.instance.checkConnectivityAndSync();
    await _checkPendingSync();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SyncService.instance.isOnline 
              ? 'Sincronización forzada completada.' 
              : 'Dispositivo sin conexión. Los datos permanecen en la cola SQLite.'),
          backgroundColor: SyncService.instance.isOnline ? const Color(0xFF087A4B) : const Color(0xFFB91C1C),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final notifier = ref.read(authProvider.notifier);
    final pending = await notifier.hasPendingDrafts();

    if (pending && mounted) {
      // Show Warning Alert dialog (M0)
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Datos Pendientes', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              '¡Atención! Tienes gestiones o solicitudes pendientes de sincronizar en tu cola local.\n\nSi cierras sesión, se procederá al borrado de datos sensibles del dispositivo y se perderá esta información.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  notifier.logout(force: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('CERRAR SESIÓN Y BORRAR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } else {
      notifier.logout(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Perfil del Asesor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Advisor avatar card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFEC0000).withOpacity(0.08),
                    child: const Icon(Icons.support_agent, size: 40, color: Color(0xFFEC0000)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authState.advisorName ?? 'Nombre Asesor',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC0000).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PERFIL: ${authState.role.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFFEC0000),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  _ProfileRow(label: 'Código de Asesor:', value: authState.advisorCode ?? 'N/A'),
                  _ProfileRow(label: 'Canal Comercial:', value: 'Banca Retail / Consumo'),
                  _ProfileRow(label: 'Sucursal Regional:', value: 'Lima Metropolitana'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Interactivity Profile Swapping (For testing purposes - M0)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulador de Perfiles (Testing UI)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cambie el rol para ver las pantallas específicas de Supervisor o Administrador en la barra de navegación.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: authState.role,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Operador', child: Text('Operador')),
                      DropdownMenuItem(value: 'Super Operador', child: Text('Super Operador')),
                      DropdownMenuItem(value: 'Supervisor', child: Text('Supervisor (Ver Mapa Supervisores)')),
                      DropdownMenuItem(value: 'Administrador', child: Text('Administrador (Acceso Completo)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(authProvider.notifier).login(
                          authState.advisorCode ?? 'OP001',
                          'santander2026',
                          val,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Offline SQLite status & synchronization (SQLite queue - M11)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conectividad y Sincronización',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado de red:', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          Icon(
                            SyncService.instance.isOnline ? Icons.wifi : Icons.wifi_off,
                            color: SyncService.instance.isOnline ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            SyncService.instance.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: SyncService.instance.isOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gestiones en cola SQLite:', style: TextStyle(fontSize: 13)),
                      Text(
                        '$_pendingSyncCount registros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _pendingSyncCount > 0 ? const Color(0xFFDC2626) : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _forceSync,
                    icon: const Icon(Icons.sync_outlined, size: 18),
                    label: _isSyncing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('FORZAR SINCRONIZACIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Log out button
          ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
            label: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
