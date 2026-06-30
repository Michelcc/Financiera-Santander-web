import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/solicitud_model.dart';
import '../../services/cliente_supabase_service.dart';

class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<SolicitudModel> _solicitudes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
    ClienteSupabaseService.instance.subscribeToSolicitudes(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final data = await ClienteSupabaseService.instance.getSolicitudes();
    if (mounted) setState(() { _solicitudes = data; _loading = false; });
  }

  List<SolicitudModel> _filter(String cat) =>
      _solicitudes.where((s) => s.categoria == cat).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Enviadas'),
            Tab(text: 'Aprobadas'),
            Tab(text: 'Rechazadas'),
            Tab(text: 'Desembolsadas'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC0000)))
          : TabBarView(
              controller: _tabs,
              children: [
                _SolicitudList(items: _filter('Enviadas')),
                _SolicitudList(items: _filter('Aprobadas')),
                _SolicitudList(items: _filter('Rechazadas')),
                _SolicitudList(items: _filter('Desembolsadas')),
              ],
            ),
    );
  }
}

class _SolicitudList extends StatelessWidget {
  const _SolicitudList({required this.items});

  final List<SolicitudModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sin solicitudes en esta categoría'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(Formatters.money(s.monto)),
            subtitle: Text('${s.estado} · $s.plazo meses'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SolicitudDetalleScreen(solicitud: s),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SolicitudDetalleScreen extends StatelessWidget {
  const SolicitudDetalleScreen({super.key, required this.solicitud});

  final SolicitudModel solicitud;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle solicitud'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _info('Estado', solicitud.estado),
          _info('Monto', Formatters.money(solicitud.monto)),
          _info('Plazo', '${solicitud.plazo} meses'),
          if (solicitud.montoAprobado > 0)
            _info('Monto aprobado', Formatters.money(solicitud.montoAprobado)),
          if (solicitud.motivoRechazo != null)
            _info('Motivo rechazo', solicitud.motivoRechazo!),
          if (solicitud.expedienteNumero != null)
            _info('Expediente', solicitud.expedienteNumero!),
          const SizedBox(height: 20),
          const Text('Línea de tiempo',
              style: TextStyle(fontWeight: FontWeight.w800)),
          ...solicitud.timeline.map((t) => ListTile(
                leading: const Icon(Icons.circle, size: 12, color: Color(0xFFEC0000)),
                title: Text(t.estado),
                subtitle: Text(Formatters.fecha(t.fecha)),
              )),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
