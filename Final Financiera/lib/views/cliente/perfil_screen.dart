import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/perfil_viewmodel.dart';
import '../../widgets/embedded_tab_header.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';
import 'contacto_screen.dart';
import 'tarjetas_screen.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _syncFields(PerfilState state) {
    if (_initialized || state.perfil == null) return;
    _nombreCtrl.text = state.perfil!.nombre;
    _telefonoCtrl.text = state.perfil!.telefono;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(perfilProvider);
    _syncFields(state);

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: widget.embedded ? null : const SantanderAppBar(title: 'Mi Perfil'),
      body: Column(
        children: [
          if (widget.embedded) const EmbeddedTabHeader(title: 'Mi Perfil'),
          Expanded(
            child: state.isLoading && state.perfil == null
                ? const SantanderLoading(message: 'Cargando perfil...')
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: BrandColors.red.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 40, color: BrandColors.red),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.perfil?.nombre ?? 'Cliente',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'DNI ${Formatters.documentoCensurado(state.perfil?.documento ?? '')}',
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.isSaving
                              ? null
                              : () => ref.read(perfilProvider.notifier).guardar(
                                    nombre: _nombreCtrl.text,
                                    telefono: _telefonoCtrl.text,
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: BrandColors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: state.isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('GUARDAR CAMBIOS'),
                        ),
                      ),
                      if (state.saved)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Perfil actualizado',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MenuTile(
                  icon: Icons.credit_card,
                  label: 'Mis tarjetas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TarjetasScreen()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.support_agent,
                  label: 'Contacto y asesor',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactoScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout, color: BrandColors.red),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: BrandColors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: BrandColors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: BrandColors.red),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
