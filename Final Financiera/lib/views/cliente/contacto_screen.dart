import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand/brand_colors.dart';
import '../../services/cliente_supabase_service.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';

class ContactoScreen extends StatefulWidget {
  const ContactoScreen({super.key});

  @override
  State<ContactoScreen> createState() => _ContactoScreenState();
}

class _ContactoScreenState extends State<ContactoScreen> {
  Map<String, dynamic>? _asesor;
  bool _loading = true;

  static const _callCenter = '0800-12345';

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
    final clean = telefono.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/51$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SantanderLoading(message: 'Cargando contacto...'),
      );
    }

    final a = _asesor ?? {};
    final nombreAsesor = a['nombre'] ?? 'Sin asignar';
    final telAsesor = a['telefono']?.toString() ?? '';
    final agencia = a['sucursal'] ?? a['zona'] ?? '—';

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: const SantanderAppBar(title: 'Contacto'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headset_mic, color: BrandColors.red),
                    SizedBox(width: 8),
                    Text(
                      'Call Center Santander',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _callCenter,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Atención 24/7 — consultas, bloqueos y reclamos',
                  style: TextStyle(color: BrandColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _llamar(_callCenter.replaceAll('-', '')),
                    icon: const Icon(Icons.phone),
                    label: const Text('LLAMAR AL CALL CENTER'),
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent, color: BrandColors.red),
                    SizedBox(width: 8),
                    Text(
                      'Tu asesor asignado',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: BrandColors.red.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 36, color: BrandColors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  nombreAsesor,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text('Agencia: $agencia', style: const TextStyle(color: BrandColors.muted)),
                if (telAsesor.isNotEmpty)
                  Text(telAsesor, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (telAsesor.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _llamar(telAsesor),
                      icon: const Icon(Icons.phone, color: BrandColors.red),
                      label: const Text('Llamar al asesor'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _whatsapp(telAsesor),
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: ListTile(
              leading: const Icon(Icons.email_outlined, color: BrandColors.red),
              title: const Text('atencion.cliente@santander.pe'),
              subtitle: const Text('Escríbenos por correo'),
              onTap: () => _email('atencion.cliente@santander.pe'),
            ),
          ),
        ],
      ),
    );
  }
}
