import 'package:flutter/material.dart';
import '../../models/cliente_model.dart';
import '../../services/supabase_service.dart';

class BuroScreen extends StatefulWidget {
  const BuroScreen({super.key, required this.client});

  final ClienteModel client;

  @override
  State<BuroScreen> createState() => _BuroScreenState();
}

class _BuroScreenState extends State<BuroScreen> {
  bool _consentChecked = false;
  bool _isQuerying = false;
  final List<Offset?> _points = []; // Stores signature coordinates

  Future<void> _runBureauCheck() async {
    if (!_consentChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe marcar la casilla de consentimiento de Ley 29733.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    if (_points.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, solicite al cliente que firme en el recuadro.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    setState(() {
      _isQuerying = true;
    });

    // Invoke Edge Function mock via Supabase
    final result = await SupabaseService.instance.queryBureauAndRestrictions(widget.client.documento);

    setState(() {
      _isQuerying = false;
    });

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text(
          'Consulta de Buró de Crédito',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informative Header
            const Icon(
              Icons.security,
              size: 48,
              color: Color(0xFFEC0000),
            ),
            const SizedBox(height: 12),
            const Text(
              'Consulta Legal y Buró SBS',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Según la Ley N° 29733 (Protección de Datos Personales), se requiere autorización firmada del cliente para la consulta de información crediticia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Consent Box (Ley 29733)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentChecked,
                    activeColor: const Color(0xFFEC0000),
                    onChanged: (val) {
                      setState(() {
                        _consentChecked = val ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Yo, ${widget.client.nombre}, con DNI ${widget.client.documento}, autorizo a Santander Consumer Perú a consultar mis calificaciones en las centrales de riesgo y bases de prevención de fraude.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interactive Drawing Signature Board (M7)
            const Text(
              'Firma Digital de Consentimiento:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final localPos = box.globalToLocal(details.globalPosition);
                        setState(() {
                          // Compensate for drawing offset within board
                          _points.add(Offset(localPos.dx, localPos.dy - 100));
                        });
                      }
                    },
                    onPanEnd: (_) => _points.add(null),
                    child: CustomPaint(
                      painter: _SignaturePainter(points: _points),
                      size: Size.infinite,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _points.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFFEC0000)),
                      label: const Text('Limpiar', style: TextStyle(color: Color(0xFFEC0000), fontSize: 12)),
                    ),
                  ),
                  if (_points.isEmpty)
                    const Center(
                      child: Text(
                        'Firme aquí con el dedo',
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit check button
            ElevatedButton(
              onPressed: _isQuerying ? null : _runBureauCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isQuerying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'AUTORIZAR Y CONSULTAR',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.points});

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
