import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notificacion_model.dart';
import '../../viewmodels/notificaciones_viewmodel.dart';
import '../../widgets/embedded_tab_header.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificacionesProvider);

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: embedded ? null : const SantanderAppBar(title: 'Notificaciones'),
      body: Column(
        children: [
          if (embedded) const EmbeddedTabHeader(title: 'Alertas'),
          Expanded(
            child: state.isLoading
                ? const SantanderLoading(message: 'Cargando alertas...')
                : RefreshIndicator(
              color: BrandColors.red,
              onRefresh: () => ref.read(notificacionesProvider.notifier).load(),
              child: state.items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No tienes notificaciones')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) => _NotifTile(
                        notif: state.items[i],
                        onTap: () => ref
                            .read(notificacionesProvider.notifier)
                            .marcarLeida(state.items[i].id),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onTap});

  final NotificacionModel notif;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notif.tipo) {
      case 'aprobacion':
        return Icons.check_circle_outline;
      case 'rechazo':
        return Icons.cancel_outlined;
      case 'mora':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: notif.leida ? null : onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: notif.leida ? BrandColors.muted : BrandColors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: notif.leida ? BrandColors.muted : BrandColors.ink,
                            ),
                          ),
                        ),
                        if (!notif.leida)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: BrandColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notif.mensaje.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notif.mensaje,
                        style: const TextStyle(fontSize: 13, color: BrandColors.muted),
                      ),
                    ],
                    if (notif.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        Formatters.fecha(notif.createdAt),
                        style: const TextStyle(fontSize: 11, color: BrandColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
