import 'package:flutter/material.dart';

class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    // Score transaccional goes 0 to 800
    final progress = (score.clamp(0, 800)) / 800;
    
    Color progressColor = const Color(0xFFDC2626); // Red
    String status = 'Riesgo Alto';
    if (score >= 750) {
      progressColor = const Color(0xFFD4AF37); // Gold
      status = 'Excelente / Premier';
    } else if (score >= 550) {
      progressColor = const Color(0xFF087A4B); // Green / Estándar
      status = 'Bueno / Estándar';
    } else if (score >= 350) {
      progressColor = const Color(0xFF3B82F6); // Blue / Básico
      status = 'Regular / Básico';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Score Transaccional',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87),
            ),
            Text(
              '$score / 800',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: progressColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calificación SBS: $status',
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Escala Santander 0-800',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}
