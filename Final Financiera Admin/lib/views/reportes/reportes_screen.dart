import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte PDF exportado y guardado en descargas localmente.'),
          backgroundColor: Color(0xFF087A4B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSupervisorOrAdmin = authState.role == 'Supervisor' || authState.role == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text('Reportes de Productividad', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: isSupervisorOrAdmin
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.show_chart), text: 'MI PRODUCTIVIDAD'),
                  Tab(icon: Icon(Icons.supervisor_account), text: 'SUPERVISIÓN CAMPO'),
                ],
              )
            : null,
      ),
      body: isSupervisorOrAdmin
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalProductivity(),
                _buildSupervisorPanel(),
              ],
            )
          : _buildPersonalProductivity(),
    );
  }

  Widget _buildPersonalProductivity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header summary cards
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Solicitudes',
                  value: '18',
                  subtitle: 'Este mes',
                  color: const Color(0xFFEC0000),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Aprobación',
                  value: '83%',
                  subtitle: '15 aprobadas',
                  color: const Color(0xFF087A4B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Desembolsado',
                  value: 'S/ 38.5K',
                  subtitle: 'Meta: S/ 50K',
                  color: const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly placement chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Colocación de Créditos Mensual (Soles)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: _barBottomTitleWidgets,
                              reservedSize: 24,
                            ),
                          ),
                        ),
                        barGroups: [
                          _makeBarGroup(0, 15000),
                          _makeBarGroup(1, 28000),
                          _makeBarGroup(2, 22000),
                          _makeBarGroup(3, 38500),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Export button
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('EXPORTAR REPORTE MENSUAL PDF', style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Advisor Comparison Chart (M11)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Colocación Comparativa por Asesor (S/ K)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: _advBottomTitleWidgets,
                              reservedSize: 24,
                            ),
                          ),
                        ),
                        barGroups: [
                          _makeBarGroup(0, 38.5, color: const Color(0xFFEC0000)), // Me
                          _makeBarGroup(1, 45.0, color: Colors.indigo), // Adv 1
                          _makeBarGroup(2, 29.5, color: Colors.amber), // Adv 2
                          _makeBarGroup(3, 52.0, color: Colors.green), // Adv 3
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live GPS Tracker (M11)
          const Text(
            'Mapa de Supervisión en Vivo (Asesores en Campo)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                // Render Canvas representing Multiple advisors coordinates
                CustomPaint(
                  size: Size.infinite,
                  painter: _SupervisorMapPainter(),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Puntos en tiempo real',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, {Color color = const Color(0xFFEC0000)}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }
}

Widget _barBottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold);
  final labels = ['Marzo', 'Abril', 'Mayo', 'Junio (Hoy)'];
  final index = value.toInt();
  if (index >= 0 && index < labels.length) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(labels[index], style: style),
    );
  }
  return const SizedBox.shrink();
}

Widget _advBottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold);
  final labels = ['Tú (OP001)', 'Pedro (OP002)', 'Ana (OP003)', 'Luis (OP004)'];
  final index = value.toInt();
  if (index >= 0 && index < labels.length) {
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(labels[index], style: style),
    );
  }
  return const SizedBox.shrink();
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle, required this.color});
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// Custom painter to draw live active tracks of advisors on map grid (M11)
class _SupervisorMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw grid streets
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0;

    for (int i = 0; i < 6; i++) {
      canvas.drawLine(Offset(0, (h / 6) * i), Offset(w, (h / 6) * i), roadPaint);
      canvas.drawLine(Offset((w / 6) * i, 0), Offset((w / 6) * i, h), roadPaint);
    }

    // Draw geofence perimeter
    final perimeterPaint = Paint()
      ..color = Colors.green.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(20, 20, w - 40, h - 40), perimeterPaint);

    // Draw active advisor dots with labels
    final advPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final List<Map<String, dynamic>> advisors = [
      {'name': 'Tú (OP001)', 'pos': Offset(w * 0.3, h * 0.4), 'color': const Color(0xFFEC0000)},
      {'name': 'Pedro (OP002)', 'pos': Offset(w * 0.7, h * 0.3), 'color': Colors.indigo},
      {'name': 'Ana (OP003)', 'pos': Offset(w * 0.5, h * 0.7), 'color': Colors.amber},
      {'name': 'Luis (OP004)', 'pos': Offset(w * 0.2, h * 0.8), 'color': Colors.green},
    ];

    for (final adv in advisors) {
      final pos = adv['pos'] as Offset;
      final color = adv['color'] as Color;
      final name = adv['name'] as String;

      // Draw dot
      advPaint.color = color;
      canvas.drawCircle(pos, 6.0, advPaint);

      // Label text
      textPainter.text = TextSpan(
        text: name,
        style: TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.bold, backgroundColor: Colors.white.withOpacity(0.8)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx + 8, pos.dy - 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
