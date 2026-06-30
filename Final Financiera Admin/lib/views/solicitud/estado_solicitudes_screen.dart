import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';

class EstadoSolicitudesScreen extends StatefulWidget {
  const EstadoSolicitudesScreen({super.key});

  @override
  State<EstadoSolicitudesScreen> createState() =>
      _EstadoSolicitudesScreenState();
}

class _EstadoSolicitudesScreenState extends State<EstadoSolicitudesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  final List<String> _stages = [
    'Enviado',
    'Pendiente',
    'Evaluación',
    'Aprobado',
    'Desembolsado',
    'Rechazado',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stages.length, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _estadoDe(Map<String, dynamic> app) =>
      (app['estado'] ?? 'Enviado').toString();

  bool _matchStage(String estado, String stage) {
    final e = estado.toLowerCase();
    final s = stage.toLowerCase();
    if (s == 'enviado') return e.contains('enviad');
    if (s == 'pendiente') return e.contains('pendient') || e.contains('borrador');
    if (s == 'evaluación') return e.contains('evalu');
    if (s == 'aprobado') return e.contains('aprob') && !e.contains('desembols');
    if (s == 'desembolsado') return e.contains('desembols');
    if (s == 'rechazado') return e.contains('rechaz');
    return false;
  }

  dynamic _jsonField(dynamic v) {
    if (v == null) return {};
    if (v is Map) return v;
    try {
      return jsonDecode(v as String);
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.instance.fetchSolicitudes();
    if (mounted) {
      setState(() {
        _applications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _resolver(
    Map<String, dynamic> app,
    String decision, {
    String? motivo,
  }) async {
    final cond = _jsonField(app['condiciones']);
    final monto = (cond['monto'] as num?)?.toDouble() ??
        (app['monto_aprobado'] as num?)?.toDouble();
    final plazo = (cond['plazo'] as num?)?.toInt() ??
        (app['plazo_aprobado'] as num?)?.toInt();

    try {
      await SupabaseService.instance.resolverSolicitud(
        solicitudId: app['id'] as String,
        decision: decision,
        montoAprobado: monto,
        plazo: plazo,
        motivo: motivo,
      );
      await _loadApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud $decision — sincronizado con App Cliente'),
          backgroundColor: const Color(0xFF087A4B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes (Supabase)'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _stages.map((s) => Tab(text: s.toUpperCase())).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _stages.map((stage) {
                final filtered = _applications
                    .where((a) => _matchStage(_estadoDe(a), stage))
                    .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin solicitudes en "$stage".\n'
                      'Las solicitudes del App Cliente aparecen en Enviado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final app = filtered[i];
                    final dp = _jsonField(app['datos_personales']);
                    final cond = _jsonField(app['condiciones']);
                    final nombre = dp['nombre'] ?? 'Cliente';
                    final monto = cond['monto'] ?? app['monto_aprobado'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(nombre.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'S/ $monto · ${cond['plazo'] ?? app['plazo_aprobado']} meses\n'
                          'Exp: ${app['expediente_numero'] ?? app['id']}',
                        ),
                        isThreeLine: true,
                        trailing: _actionsFor(app),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget? _actionsFor(Map<String, dynamic> app) {
    final e = _estadoDe(app).toLowerCase();
    if (e.contains('enviad') || e.contains('pendient')) {
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'aprobar') _resolver(app, 'APROBADO');
          if (v == 'rechazar') {
            _resolver(app, 'RECHAZADO', motivo: 'No califica en evaluación');
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'aprobar', child: Text('Aprobar')),
          PopupMenuItem(value: 'rechazar', child: Text('Rechazar')),
        ],
      );
    }
    if (e.contains('aprob') && !e.contains('desembols')) {
      return IconButton(
        icon: const Icon(Icons.payments, color: Color(0xFF087A4B)),
        tooltip: 'Desembolsar → crédito en App Cliente',
        onPressed: () => _resolver(app, 'DESEMBOLSADO'),
      );
    }
    return null;
  }
}
