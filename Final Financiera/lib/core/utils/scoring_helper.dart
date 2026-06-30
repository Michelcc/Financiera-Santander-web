import 'package:flutter/material.dart';

class ScoringHelper {
  static const maxTransaccional = 800;
  static const maxCampo = 200;
  static const maxFinal = 1000;

  static String segmentoLabel(String? segmento) {
    switch (segmento?.toUpperCase()) {
      case 'PREMIER':
        return 'PREMIER';
      case 'ESTANDAR':
      case 'ESTÁNDAR':
        return 'ESTANDAR';
      case 'BASICO':
      case 'BÁSICO':
        return 'BASICO';
      default:
        return 'ESTANDAR';
    }
  }

  static Color segmentoColor(String? segmento) {
    switch (segmento?.toUpperCase()) {
      case 'PREMIER':
        return const Color(0xFFC99A18);
      case 'ESTANDAR':
      case 'ESTÁNDAR':
        return const Color(0xFF1565C0);
      case 'BASICO':
      case 'BÁSICO':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF1565C0);
    }
  }

  static Color segmentoBackground(String? segmento) {
    return segmentoColor(segmento).withValues(alpha: 0.12);
  }

  static double scoreProgress(int score) => (score / maxFinal).clamp(0.0, 1.0);
}
