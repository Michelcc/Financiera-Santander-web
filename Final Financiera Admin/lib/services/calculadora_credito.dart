import 'dart:math';

class ResultadoSimulacion {
  const ResultadoSimulacion({
    required this.monto,
    required this.plazoCuotas,
    required this.frecuencia,
    required this.tea,
    required this.tep, // Tasa efectiva por periodo
    required this.cuotaMonto,
    required this.totalPagar,
    required this.costoFinancieroTotal,
  });

  final double monto;
  final int plazoCuotas;
  final String frecuencia; // Mensual, Quincenal, Semanal
  final double tea;
  final double tep;
  final double cuotaMonto;
  final double totalPagar;
  final double costoFinancieroTotal;
}

class CuotaAmortizacion {
  const CuotaAmortizacion({
    required this.numero,
    required this.fechaVencimiento,
    required this.cuota,
    required this.interes,
    required this.capital,
    required this.saldo,
  });

  final int numero;
  final DateTime fechaVencimiento;
  final double cuota;
  final double interes;
  final double capital;
  final double saldo;
}

class CalculadoraCredito {
  static const double teaReferencial = 0.45; // 45% standard TEA

  // Convert TEA to tasa efectiva del periodo based on payment frequency
  static double teaToTep(double tea, String frecuencia) {
    final periodsPerYear = _getPeriodsPerYear(frecuencia);
    return pow(1 + tea, 1 / periodsPerYear).toDouble() - 1;
  }

  static int _getPeriodsPerYear(String frecuencia) {
    switch (frecuencia.trim().toLowerCase()) {
      case 'semanal':
        return 52;
      case 'quincenal':
        return 24;
      case 'mensual':
      default:
        return 12;
    }
  }

  static double cuotaFrancesa({
    required double monto,
    required int plazoCuotas,
    required String frecuencia,
    double tea = teaReferencial,
  }) {
    if (monto <= 0 || plazoCuotas <= 0) return 0;
    final tep = teaToTep(tea, frecuencia);
    if (tep == 0) return monto / plazoCuotas;
    final factor = pow(1 + tep, plazoCuotas).toDouble();
    return monto * (tep * factor) / (factor - 1);
  }

  static ResultadoSimulacion simular({
    required double monto,
    required int plazoCuotas,
    required String frecuencia,
    double tea = teaReferencial,
  }) {
    final tep = teaToTep(tea, frecuencia);
    final cuota = cuotaFrancesa(
      monto: monto,
      plazoCuotas: plazoCuotas,
      frecuencia: frecuencia,
      tea: tea,
    );
    final total = cuota * plazoCuotas;
    return ResultadoSimulacion(
      monto: monto,
      plazoCuotas: plazoCuotas,
      frecuencia: frecuencia,
      tea: tea,
      tep: tep,
      cuotaMonto: cuota,
      totalPagar: total,
      costoFinancieroTotal: total - monto,
    );
  }

  static List<CuotaAmortizacion> generarAmortizacion({
    required double monto,
    required int plazoCuotas,
    required String frecuencia,
    DateTime? fechaDesembolso,
    double tea = teaReferencial,
  }) {
    final cuota = cuotaFrancesa(
      monto: monto,
      plazoCuotas: plazoCuotas,
      frecuencia: frecuencia,
      tea: tea,
    );
    final tep = teaToTep(tea, frecuencia);
    var saldo = monto;
    final inicio = fechaDesembolso ?? DateTime.now();

    final daysInterval = _getDaysInterval(frecuencia);

    return List.generate(plazoCuotas, (index) {
      final interes = saldo * tep;
      final capital = cuota - interes;
      saldo = max(0, saldo - capital);
      
      final fechaVencimiento = inicio.add(Duration(days: daysInterval * (index + 1)));

      return CuotaAmortizacion(
        numero: index + 1,
        fechaVencimiento: fechaVencimiento,
        cuota: cuota,
        interes: interes,
        capital: capital,
        saldo: saldo,
      );
    });
  }

  static int _getDaysInterval(String frecuencia) {
    switch (frecuencia.trim().toLowerCase()) {
      case 'semanal':
        return 7;
      case 'quincenal':
        return 15;
      case 'mensual':
      default:
        return 30;
    }
  }
}
