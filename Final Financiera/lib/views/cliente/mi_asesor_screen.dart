import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/cliente_supabase_service.dart';

class MiAsesorScreen extends StatefulWidget {
  const MiAsesorScreen({super.key});

  @override
  State<MiAsesorScreen> createState() => _MiAsesorScreenState();
}

class _MiAsesorScreenState extends State<MiAsesorScreen> {
  Map<String, dynamic>? _asesor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ClienteSupabaseService.instance.getMiAsesor();
    if (mounted) setState(() { _asesor = data; _loading = false; });
  }

  Future<void> _llamar(String telefono) async {
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String telefono) async {
    final uri = Uri.parse('https://wa.me/51$telefono');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEC0000)),
        ),
      );
    }

    final a = _asesor ?? {};
    final nombre = a['nombre'] ?? 'Sin asignar';
    final telefono = a['telefono'] ?? '';
    final agencia = a['sucursal'] ?? a['zona'] ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Asesor'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFFEC0000).withValues(alpha: 0.1),
              child: const Icon(Icons.support_agent, size: 48, color: Color(0xFFEC0000)),
            ),
            const SizedBox(height: 16),
            Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('Agencia: $agencia', style: const TextStyle(color: Colors.grey)),
            if (telefono.isNotEmpty)
              Text(telefono, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            if (telefono.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _llamar(telefono),
                  icon: const Icon(Icons.phone),
                  label: const Text('LLAMAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _whatsapp(telefono),
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  label: const Text('WHATSAPP'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
