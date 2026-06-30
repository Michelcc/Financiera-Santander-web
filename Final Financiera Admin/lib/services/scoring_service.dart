import 'dart:math';
import 'calculadora_credito.dart';

class ScoringResult {
  const ScoringResult({
    required this.scoreCampo,
    required this.scoreFinal,
    required this.segmento,
    required this.montoMaximo,
    required this.plazoMaximoMeses,
    required this.tasaInteres,
    required this.aprobado,
    required this.motivoRechazo,
  });

  final int scoreCampo;
  final int scoreFinal;
  final String segmento; // PREMIER, ESTÁNDAR, BÁSICO, NO APLICA
  final double montoMaximo;
  final int plazoMaximoMeses;
  final double tasaInteres;
  final bool aprobado;
  final String motivoRechazo;
}

class ScoringService {
  // Evaluates field scoring (F1 to F5) and applies business rules
  static ScoringResult evaluar({
    required int scoreTransaccional,
    required double ingresoPromedio,
    // F1: Verificación física (max 60)
    required bool negocioVerificado,
    required int f1AntiguedadPuntos, // e.g. 0-20
    required int f1LocalTenenciaPuntos, // e.g. 0-40
    // F2: Ventas y gastos (max 60)
    required int f2ConsistenciaVentasPuntos, // 0-30
    required int f2ControlGastosPuntos, // 0-30
    // F3: Deuda informal (-50 a +40)
    required int f3DeudaInformalPuntos, // -50 a 40
    // F4: Activos y stock (max 40)
    required int f4StockActivosPuntos, // 0-40
    // F5: Veto
    required bool f5VetoCaracter,
  }) {
    // 1. Immediate disqualification rules
    if (!negocioVerificado) {
      return const ScoringResult(
        scoreCampo: 0,
        scoreFinal: 0,
        segmento: 'NO APLICA',
        montoMaximo: 0,
        plazoMaximoMeses: 0,
        tasaInteres: 0,
        aprobado: false,
        motivoRechazo: 'Negocio no verificado físicamente en campo.',
      );
    }

    if (f5VetoCaracter) {
      return const ScoringResult(
        scoreCampo: 0,
        scoreFinal: 0,
        segmento: 'NO APLICA',
        montoMaximo: 0,
        plazoMaximoMeses: 0,
        tasaInteres: 0,
        aprobado: false,
        motivoRechazo: 'Descalificado por veto de carácter (F5).',
      );
    }

    // 2. Calculate field score
    final f1 = min(60, max(0, f1AntiguedadPuntos + f1LocalTenenciaPuntos));
    final f2 = min(60, max(0, f2ConsistenciaVentasPuntos + f2ControlGastosPuntos));
    final f3 = min(40, max(-50, f3DeudaInformalPuntos));
    final f4 = min(40, max(0, f4StockActivosPuntos));

    final scoreCampo = f1 + f2 + f3 + f4; // max 200, min -50
    final scoreFinal = max(0, min(1000, scoreTransaccional + scoreCampo));

    // 3. Define Segment
    String segmento;
    double techoSegmento;
    int plazoMaximo;
    double tasa;

    if (scoreFinal >= 750) {
      segmento = 'PREMIER';
      techoSegmento = 5000.0;
      plazoMaximo = 12;
      tasa = 0.35; // 35% TEA
    } else if (scoreFinal >= 550) {
      segmento = 'ESTÁNDAR';
      techoSegmento = 2500.0;
      plazoMaximo = 6;
      tasa = 0.45; // 45% TEA
    } else if (scoreFinal >= 350) {
      segmento = 'BÁSICO';
      techoSegmento = 1000.0;
      plazoMaximo = 3;
      tasa = 0.55; // 55% TEA
    } else {
      segmento = 'NO APLICA';
      techoSegmento = 0.0;
      plazoMaximo = 0;
      tasa = 0.0;
    }

    if (segmento == 'NO APLICA') {
      return ScoringResult(
        scoreCampo: scoreCampo,
        scoreFinal: scoreFinal,
        segmento: segmento,
        montoMaximo: 0,
        plazoMaximoMeses: 0,
        tasaInteres: 0,
        aprobado: false,
        motivoRechazo: 'Puntaje final ($scoreFinal) por debajo del mínimo (350).',
      );
    }

    // 4. Calculate Final Loan Limit based on income rules
    // Rule A: Segment limit
    // Rule B: 2x average monthly income in account
    final limiteIngreso = 2 * ingresoPromedio;

    // Rule C: Monto that generates cuota <= 30% of income
    // Let's find the maximum amount that gives a cuota equal to 30% of income.
    // Cuota = 30% of ingreso
    final cuotaMaxima = ingresoPromedio * 0.30;
    
    // We can invert the French formula to find the principal (monto):
    // Cuota = P * (r * (1+r)^n) / ((1+r)^n - 1)
    // P = Cuota * ((1+r)^n - 1) / (r * (1+r)^n)
    final tep = CalculadoraCredito.teaToTep(tasa, 'mensual');
    final factor = pow(1 + tep, plazoMaximo).toDouble();
    final factorAmortizacion = (tep * factor) / (factor - 1);
    final limiteCuota = cuotaMaxima / factorAmortizacion;

    // The final maximum amount is the minimum of these three limits
    final montoMaximoCalculado = min(techoSegmento, min(limiteIngreso, limiteCuota));

    // Ensure it's a positive round number or 0 if too low
    final montoFinal = max(0.0, (montoMaximoCalculado / 100).floor() * 100.0);

    if (montoFinal < 200) {
      return ScoringResult(
        scoreCampo: scoreCampo,
        scoreFinal: scoreFinal,
        segmento: segmento,
        montoMaximo: 0,
        plazoMaximoMeses: 0,
        tasaInteres: 0,
        aprobado: false,
        motivoRechazo: 'La capacidad de pago calculada (S/ $montoFinal) es menor al monto mínimo de desembolso (S/ 200).',
      );
    }

    return ScoringResult(
      scoreCampo: scoreCampo,
      scoreFinal: scoreFinal,
      segmento: segmento,
      montoMaximo: montoFinal,
      plazoMaximoMeses: plazoMaximo,
      tasaInteres: tasa,
      aprobado: true,
      motivoRechazo: '',
    );
  }
}
