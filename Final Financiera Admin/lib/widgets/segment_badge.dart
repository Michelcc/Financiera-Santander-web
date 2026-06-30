import 'package:flutter/material.dart';
import '../models/cliente_model.dart';

class SegmentBadge extends StatelessWidget {
  const SegmentBadge({super.key, required this.segmento});

  final SegmentoCliente segmento;

  @override
  Widget build(BuildContext context) {
    final color = switch (segmento) {
      SegmentoCliente.premier => const Color(0xFFC99A18), // Gold
      SegmentoCliente.estandar => const Color(0xFF1565C0), // Blue
      SegmentoCliente.basico => const Color(0xFF4B5563), // Grey
      SegmentoCliente.noAplica => const Color(0xFFDC2626), // Red
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          segmento.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}
