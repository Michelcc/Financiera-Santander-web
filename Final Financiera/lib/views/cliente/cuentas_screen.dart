import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/movimiento_model.dart';
import '../../viewmodels/cuentas_viewmodel.dart';
import '../../widgets/embedded_tab_header.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';

class CuentasScreen extends ConsumerWidget {
  const CuentasScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cuentasProvider);

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: embedded ? null : const SantanderAppBar(title: 'Mis Cuentas'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (embedded) const EmbeddedTabHeader(title: 'Mis Cuentas'),
          Expanded(
            child: state.isLoading
          ? const SantanderLoading(message: 'Cargando cuentas...')
          : RefreshIndicator(
              color: BrandColors.red,
              onRefresh: () => ref.read(cuentasProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo total',
                          style: TextStyle(color: BrandColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.money(state.saldoTotal),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: BrandColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.cuentas.isEmpty)
                    const PremiumCard(
                      child: Text(
                        'No hay cuentas registradas. Ejecuta supabase_cliente_productos.sql en Supabase.',
                        style: TextStyle(color: BrandColors.muted),
                      ),
                    )
                  else
                    ...state.cuentas.map(_CuentaTile.new),
                  const SizedBox(height: 20),
                  const Text(
                    'Últimos movimientos',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: BrandColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state.movimientos.isEmpty)
                    const PremiumCard(
                      child: Text('Sin movimientos recientes'),
                    )
                  else
                    ...state.movimientos.map(_MovimientoTile.new),
                  if (state.error != null &&
                      !state.error!.contains('cuentas_ahorro')) ...[
                    const SizedBox(height: 12),
                    Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaTile extends StatelessWidget {
  const _CuentaTile(this.cuenta);

  final dynamic cuenta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BrandColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.savings_outlined, color: BrandColors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cuenta.tipoCuenta?.toUpperCase() ?? 'AHORRO',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    cuenta.codCuentaAhorro,
                    style: const TextStyle(color: BrandColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.money(cuenta.saldoCapital),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  cuenta.estado,
                  style: TextStyle(
                    fontSize: 11,
                    color: cuenta.estado == 'activa' ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile(this.mov);

  final MovimientoModel mov;

  @override
  Widget build(BuildContext context) {
    final esNegativo = mov.esDebito || mov.esTransferencia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              esNegativo ? Icons.arrow_upward : Icons.arrow_downward,
              color: esNegativo ? Colors.red : Colors.green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mov.concepto ?? mov.tipo ?? 'Operación',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    Formatters.fecha(mov.fechaOperacion),
                    style: const TextStyle(fontSize: 11, color: BrandColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${esNegativo ? '-' : '+'}${Formatters.money(mov.monto)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: esNegativo ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
