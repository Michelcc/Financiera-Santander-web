import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/credito_model.dart';
import '../../services/calculadora_credito.dart';
import '../../services/cliente_supabase_service.dart';

class CreditosScreen extends StatefulWidget {
  const CreditosScreen({super.key});

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> {
  List<CreditoModel> _creditos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ClienteSupabaseService.instance.getCreditos();
      if (mounted) setState(() { _creditos = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _creditos = []; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando créditos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Créditos'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC0000)))
          : _creditos.isEmpty
              ? const Center(child: Text('No tienes créditos activos'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _creditos.length,
                  itemBuilder: (context, index) {
                    final c = _creditos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          Formatters.money(c.monto),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${c.estado} · ${c.plazoMeses} meses'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreditoDetalleScreen(credito: c),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class CreditoDetalleScreen extends StatelessWidget {
  const CreditoDetalleScreen({super.key, required this.credito});

  final CreditoModel credito;

  @override
  Widget build(BuildContext context) {
    final amortizacion = CalculadoraCredito.generarAmortizacion(
      monto: credito.monto,
      plazoMeses: credito.plazoMeses,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del crédito'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 180,
            child: _ComportamientoChart(pagos: credito.pagos),
          ),
          const SizedBox(height: 20),
          const Text('Tabla de amortización',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          ...amortizacion.map((c) => ListTile(
                dense: true,
                title: Text('Cuota ${c.numero}'),
                subtitle: Text(
                  'Capital: ${Formatters.money(c.capital)} · Interés: ${Formatters.money(c.interes)}',
                ),
                trailing: Text(Formatters.money(c.cuota)),
              )),
        ],
      ),
    );
  }
}

class _ComportamientoChart extends StatelessWidget {
  const _ComportamientoChart({required this.pagos});

  final List<PagoCreditoModel> pagos;

  @override
  Widget build(BuildContext context) {
    final ultimos = pagos.take(12).toList();
    if (ultimos.isEmpty) {
      return const Center(child: Text('Sin historial de pagos'));
    }

    return BarChart(
      BarChartData(
        maxY: 1,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: ultimos.asMap().entries.map((e) {
          final p = e.value;
          Color color;
          if (p.estado != 'PAGADO') {
            color = Colors.grey;
          } else if (p.pagadoConMora) {
            color = Colors.red;
          } else {
            color = Colors.green;
          }
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: 1,
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
