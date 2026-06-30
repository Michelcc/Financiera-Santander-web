import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/brand/brand_colors.dart';
import '../../services/supabase_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AlertasScreen extends ConsumerStatefulWidget {
  const AlertasScreen({super.key});

  @override
  ConsumerState<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends ConsumerState<AlertasScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _cargar();
    _channel = SupabaseService.instance.subscribeNotificaciones(_cargar);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _cargar() async {
    final role = ref.read(authProvider).role;
    final data = await SupabaseService.instance.fetchNotificaciones(role: role);
    if (mounted) {
      setState(() {
        _items = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final isSupervisor = role == 'Supervisor' || role == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        title: Text(isSupervisor ? 'Alertas de supervisión' : 'Mis alertas'),
        backgroundColor: BrandColors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: BrandColors.red))
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Sin alertas pendientes.\nLas nuevas solicitudes de clientes aparecerán aquí en tiempo real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      final leida = n['leida'] == true;
                      return Card(
                        color: leida ? null : const Color(0xFFFFF5F5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: leida
                                ? Colors.grey.shade300
                                : BrandColors.red.withValues(alpha: 0.15),
                            child: Icon(
                              n['tipo'] == 'NUEVA_SOLICITUD'
                                  ? Icons.notifications_active
                                  : Icons.info_outline,
                              color: leida ? Colors.grey : BrandColors.red,
                            ),
                          ),
                          title: Text(
                            n['titulo']?.toString() ?? 'Alerta',
                            style: TextStyle(
                              fontWeight: leida ? FontWeight.w600 : FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(n['mensaje']?.toString() ?? ''),
                          trailing: leida
                              ? null
                              : TextButton(
                                  child: const Text('Leída'),
                                  onPressed: () async {
                                    await SupabaseService.instance
                                        .marcarNotificacionLeida(n['id'] as String);
                                    _cargar();
                                  },
                                ),
                          onTap: () async {
                            if (!leida) {
                              await SupabaseService.instance
                                  .marcarNotificacionLeida(n['id'] as String);
                            }
                            _cargar();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
