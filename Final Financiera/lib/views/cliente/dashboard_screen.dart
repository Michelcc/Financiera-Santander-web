import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../core/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../widgets/animated_entrance.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';
import '../../widgets/score_card.dart';
import 'contacto_screen.dart';
import 'creditos_screen.dart';
import 'deuda_informal_screen.dart';
import 'mi_asesor_screen.dart';
import 'mis_solicitudes_screen.dart';
import 'simulador_screen.dart';
import 'tarjetas_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final dash = ref.watch(dashboardProvider);
    final nombre = auth.perfil?.nombre ?? 'Cliente';
    final primerNombre = nombre.split(' ').first;
    final scores = dash.scores;

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: const SantanderAppBar(),
      body: dash.isLoading
          ? const SantanderLoading(message: 'Cargando tu perfil...')
          : RefreshIndicator(
              color: BrandColors.red,
              onRefresh: () => ref.read(dashboardProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AnimatedEntrance(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $primerNombre 👋',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tu resumen financiero al día',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (scores != null)
                    AnimatedEntrance(
                      index: 1,
                      child: ScoreCard(scores: scores),
                    ),
                  const SizedBox(height: 16),
                  if (scores != null)
                    AnimatedEntrance(
                      index: 2,
                      child: _ResumenDeudas(scores: scores),
                    ),
                  const SizedBox(height: 24),
                  AnimatedEntrance(
                    index: 3,
                    child: const Text(
                      'Accesos rápidos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedEntrance(
                    index: 4,
                    child: _ActionGrid(
                      onCreditos: () => _push(context, const CreditosScreen()),
                      onSimular: () => _push(context, const SimuladorScreen()),
                      onTarjetas: () => _push(context, const TarjetasScreen()),
                      onAsesor: () => _push(context, const MiAsesorScreen()),
                      onContacto: () => _push(context, const ContactoScreen()),
                      onDeuda: () =>
                          _push(context, const DeudaInformalScreen()),
                      onSolicitudes: () =>
                          _push(context, const MisSolicitudesScreen()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ResumenDeudas extends StatelessWidget {
  const _ResumenDeudas({required this.scores});

  final dynamic scores;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: BrandColors.red, size: 22),
              SizedBox(width: 8),
              Text(
                'Resumen de deudas',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('Deuda total', Formatters.money(scores.deudaTotal)),
          _row(
            'Próxima cuota',
            scores.proximaCuotaMonto > 0
                ? '${Formatters.money(scores.proximaCuotaMonto)} - ${Formatters.fecha(scores.proximaCuotaFecha)}'
                : '—',
          ),
          _row(
            'Estado',
            scores.alDia
                ? '✅ Al día'
                : '⚠️ En mora (${scores.moraDias} días)',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label', style: const TextStyle(color: BrandColors.muted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onCreditos,
    required this.onSimular,
    required this.onTarjetas,
    required this.onAsesor,
    required this.onContacto,
    required this.onDeuda,
    required this.onSolicitudes,
  });

  final VoidCallback onCreditos;
  final VoidCallback onSimular;
  final VoidCallback onTarjetas;
  final VoidCallback onAsesor;
  final VoidCallback onContacto;
  final VoidCallback onDeuda;
  final VoidCallback onSolicitudes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.account_balance_wallet,
          label: 'Mis Créditos',
          onTap: onCreditos,
          index: 0,
        ),
        _ActionButton(
          icon: Icons.calculate_outlined,
          label: 'Simular',
          onTap: onSimular,
          index: 1,
        ),
        _ActionButton(
          icon: Icons.credit_card,
          label: 'Tarjetas',
          onTap: onTarjetas,
          index: 2,
        ),
        _ActionButton(
          icon: Icons.support_agent,
          label: 'Mi Asesor',
          onTap: onAsesor,
          index: 3,
        ),
        _ActionButton(
          icon: Icons.headset_mic,
          label: 'Contacto',
          onTap: onContacto,
          index: 4,
        ),
        _ActionButton(
          icon: Icons.warning_amber_outlined,
          label: 'Deuda Informal',
          onTap: onDeuda,
          index: 5,
        ),
        _ActionButton(
          icon: Icons.assignment_outlined,
          label: 'Mis Solicitudes',
          onTap: onSolicitudes,
          index: 6,
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.index,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int index;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;

    return AnimatedEntrance(
      index: widget.index + 5,
      child: SizedBox(
        width: width,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: PremiumCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x14EC0000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: BrandColors.red, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
