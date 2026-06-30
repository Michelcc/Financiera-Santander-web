import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/cliente_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/score_bar.dart';
import '../../widgets/segment_badge.dart';
import 'buro_screen.dart';
import '../solicitud/solicitud_wizard_screen.dart';

class FichaClienteScreen extends StatefulWidget {
  const FichaClienteScreen({super.key, required this.client});

  final ClienteModel client;

  @override
  State<FichaClienteScreen> createState() => _FichaClienteScreenState();
}

class _FichaClienteScreenState extends State<FichaClienteScreen> {
  bool _buroChecked = false;
  bool _isBlacklisted = false;
  String _bureauRating = 'Normal';
  double _bureauDebt = 0.0;
  int _bureauMora = 0;
  late int _scoreCampo;
  String _caracter = 'Bueno';
  bool _savingScore = false;

  @override
  void initState() {
    super.initState();
    _scoreCampo = widget.client.scoreCampo;
  }

  int get _scoreFinal =>
      widget.client.scoreTransaccional + _scoreCampo;

  double get _hipotesis => _scoreFinal * 100;

  bool get _bloqueadoSolicitud =>
      _caracter == 'Veto' || _caracter == 'Malo';

  Future<void> _guardarScoreCampo() async {
    setState(() => _savingScore = true);
    await SupabaseService.instance.updateScoreCampo(
      widget.client.id,
      _scoreCampo,
    );
    if (mounted) {
      setState(() => _savingScore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score de campo guardado')),
      );
    }
  }

  void _onCaracterChanged(String caracter) {
    setState(() {
      _caracter = caracter;
      if (caracter == 'Veto' || caracter == 'Malo') {
        _scoreCampo = 0;
      } else if (caracter == 'Bueno') {
        _scoreCampo = 50;
      } else if (caracter == 'Regular') {
        _scoreCampo = 25;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMora = widget.client.moraDias > 0 || (double.tryParse(widget.client.deudaTotal.toString()) ?? 0.0) > 3000 && widget.client.moraDias > 15;
    final segmento = SegmentoCliente.fromText(
      widget.client.segmento,
      _scoreFinal,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text(
          'Expediente del Cliente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Client main header card with avatar
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFEC0000).withOpacity(0.08),
                          child: const Icon(Icons.person, size: 36, color: Color(0xFFEC0000)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.client.nombre,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DNI: ${widget.client.documento}',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SegmentBadge(segmento: segmento),
                                  const SizedBox(width: 8),
                                  if (hasMora)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDE8E8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFF8B4B4)),
                                      ),
                                      child: const Text(
                                        'MORA ACTIVA',
                                        style: TextStyle(
                                          color: Color(0xFF9B1C1C),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    ScoreBar(score: widget.client.scoreTransaccional),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scoring transaccional + campo (HU-11 a HU-14)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SCORES ACTUALES',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _scoreLine('Score Transaccional', '${widget.client.scoreTransaccional}'),
                    Row(
                      children: [
                        const Text('Score de Campo:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          onPressed: _bloqueadoSolicitud
                              ? null
                              : () => setState(() => _scoreCampo = (_scoreCampo - 10).clamp(-50, 150)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_scoreCampo', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        IconButton(
                          onPressed: _bloqueadoSolicitud
                              ? null
                              : () => setState(() => _scoreCampo = (_scoreCampo + 10).clamp(-50, 150)),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const Divider(),
                    _scoreLine('Score Final', '$_scoreFinal'),
                    _scoreLine('Hipótesis de Crédito', 'S/ ${_hipotesis.toStringAsFixed(0)}'),
                    Row(
                      children: [
                        const Text('Segmento:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        SegmentBadge(segmento: segmento),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EVALUACIÓN CUALITATIVA',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Bueno', 'Regular', 'Malo', 'Veto'].map((c) {
                        final selected = _caracter == c;
                        return ChoiceChip(
                          label: Text(c),
                          selected: selected,
                          selectedColor: const Color(0xFFEC0000).withValues(alpha: 0.15),
                          onSelected: (_) => _onCaracterChanged(c),
                        );
                      }).toList(),
                    ),
                    if (_bloqueadoSolicitud)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Veto o carácter malo: score_campo = 0. Solicitud bloqueada.',
                          style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _savingScore ? null : _guardarScoreCampo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC0000),
                        foregroundColor: Colors.white,
                      ),
                      child: _savingScore
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('GUARDAR SCORE DE CAMPO'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Oferta Preaprobada Card (M3)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: const Color(0xFFFFF5F5), // Light warm red Santander color
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_offer, color: Color(0xFFEC0000)),
                        SizedBox(width: 8),
                        Text(
                          'Oferta Preaprobada Santander',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFEC0000)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OfferMetric(
                          label: 'Monto Máx.',
                          value: 'S/ ${widget.client.montoPreaprobado.toStringAsFixed(0)}',
                        ),
                        _OfferMetric(
                          label: 'Plazo Sugerido',
                          value: '${widget.client.plazoPreaprobado} meses',
                        ),
                        _OfferMetric(
                          label: 'Tasa (TEA)',
                          value: '${widget.client.tasaPreaprobada.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Datos Personales & Negocio
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información del Negocio',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Razón Social / Local', value: widget.client.negocioNombre),
                    _DetailRow(label: 'Giro de Negocio', value: widget.client.negocioTipo),
                    _DetailRow(label: 'Dirección Comercial', value: widget.client.direccion),
                    _DetailRow(label: 'Teléfono de Contacto', value: widget.client.telefono),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Posición Financiera
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posición Financiera Vigente',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Deuda Total Activa', 
                      value: 'S/ ${widget.client.deudaTotal.toStringAsFixed(2)}',
                    ),
                    _DetailRow(
                      label: 'Días en Mora', 
                      value: '${widget.client.moraDias} días',
                      valueColor: widget.client.moraDias > 0 ? const Color(0xFFDC2626) : Colors.black87,
                    ),
                    _DetailRow(
                      label: 'Fecha Último Pago', 
                      value: widget.client.ultimoPagoFecha.isNotEmpty ? widget.client.ultimoPagoFecha : 'Sin registro',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Historial de Pagos Gráfico (M3)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comportamiento de Pagos (Últimos 12 meses)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Monto amortizado por mes en Soles',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1.0,
                            ),
                          ),
                          titlesData: const FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: _bottomTitleWidgets,
                                reservedSize: 22,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getSpots(widget.client.historialPagosList),
                              isCurved: true,
                              color: const Color(0xFFEC0000),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFFEC0000).withOpacity(0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Buró Consent (Ley 29733) & Actions (M7)
            if (!_buroChecked)
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BuroScreen(client: widget.client),
                    ),
                  );
                  if (result is Map<String, dynamic> && result['success'] == true) {
                    setState(() {
                      _buroChecked = true;
                      _isBlacklisted = result['restriccion'] ?? false;
                      _bureauRating = result['rating_sbs'] ?? 'Normal';
                      _bureauDebt = result['deuda_total_sbs'] ?? 0.0;
                      _bureauMora = result['mora_dias'] ?? 0;
                    });
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'CONSULTAR BURÓ DE CRÉDITO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              )
            else ...[
              // Results banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isBlacklisted ? const Color(0xFFFDE8E8) : const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isBlacklisted ? const Color(0xFFF8B4B4) : const Color(0xFFA3E635),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isBlacklisted ? Icons.cancel : Icons.check_circle,
                          color: _isBlacklisted ? const Color(0xFF9B1C1C) : const Color(0xFF137333),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isBlacklisted ? 'CLIENTE BLOQUEADO' : 'BURÓ APROBADO',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _isBlacklisted ? const Color(0xFF9B1C1C) : const Color(0xFF137333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SBS Calificación: $_bureauRating • Deuda SBS: S/ $_bureauDebt • Mora: $_bureauMora días',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (_isBlacklisted) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Alerta: Cliente figura en lista negra de prevención de fraude.',
                        style: TextStyle(color: Color(0xFF9B1C1C), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isBlacklisted || _bloqueadoSolicitud
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SolicitudWizardScreen(client: widget.client),
                          ),
                        );
                      },
                icon: const Icon(Icons.description),
                label: const Text(
                  'INICIAR SOLICITUD DE CRÉDITO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getSpots(List<double> list) {
    return List.generate(list.length, (index) => FlSpot(index.toDouble() + 1, list[index]));
  }

  Widget _scoreLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

Widget _bottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold);
  final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'];
  final index = value.toInt() - 1;
  if (index >= 0 && index < months.length) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(months[index], style: style),
    );
  }
  return const SizedBox.shrink();
}

class _OfferMetric extends StatelessWidget {
  const _OfferMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEC0000))),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor = Colors.black87});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
