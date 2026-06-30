import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/tarjeta_model.dart';
import '../../viewmodels/tarjetas_viewmodel.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';

class TarjetasScreen extends ConsumerWidget {
  const TarjetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tarjetasProvider);

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: const SantanderAppBar(title: 'Mis Tarjetas'),
      body: state.isLoading
          ? const SantanderLoading(message: 'Cargando tarjetas...')
          : RefreshIndicator(
              color: BrandColors.red,
              onRefresh: () => ref.read(tarjetasProvider.notifier).load(),
              child: state.tarjetas.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No tienes tarjetas activas')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.tarjetas.length,
                      itemBuilder: (_, i) => _TarjetaCard(tarjeta: state.tarjetas[i]),
                    ),
            ),
    );
  }
}

class _TarjetaCard extends StatelessWidget {
  const _TarjetaCard({required this.tarjeta});

  final TarjetaModel tarjeta;

  @override
  Widget build(BuildContext context) {
    final uso = tarjeta.porcentajeUso.clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: BrandColors.headerGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tarjeta.marca ?? 'VISA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Icon(Icons.credit_card, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tarjeta.numeroEnmascarado,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoRow('Línea de crédito', Formatters.money(tarjeta.lineaCredito ?? 0)),
            _infoRow('Saldo utilizado', Formatters.money(tarjeta.saldoUtilizado ?? 0)),
            _infoRow('Disponible', Formatters.money(tarjeta.disponible)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: uso / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: uso > 80 ? Colors.orange : BrandColors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${uso.toStringAsFixed(0)}% de uso',
              style: const TextStyle(fontSize: 11, color: BrandColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _fechaChip(
                    'Corte',
                    Formatters.fecha(tarjeta.fechaCorte),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _fechaChip(
                    'Pago',
                    Formatters.fecha(tarjeta.fechaPago),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: BrandColors.muted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _fechaChip(String label, String fecha) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: BrandColors.muted)),
          Text(fecha, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
