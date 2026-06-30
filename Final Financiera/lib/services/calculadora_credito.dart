import 'dart:math';

import '../src/core/app_config.dart';

class ResultadoSimulacion {
  const ResultadoSimulacion({
    required this.monto,
    required this.plazoMeses,
    required this.tea,
    required this.cuotaMensual,
    required this.totalPagar,
    required this.costoFinanciero,
  });

  final double monto;
  final int plazoMeses;
  final double tea;
  final double cuotaMensual;
  final double totalPagar;
  final double costoFinanciero;
}

class CuotaAmortizacion {
  const CuotaAmortizacion({
    required this.numero,
    required this.cuota,
    required this.interes,
    required this.capital,
    required this.saldo,
  });

  final int numero;
  final double cuota;
  final double interes;
  final double capital;
  final double saldo;
}

class CalculadoraCredito {
  static double get tea => AppConfig.teaReferencial;

  static double cuotaFrancesa({
    required double monto,
    required int plazoMeses,
    double? teaOverride,
  }) {
    if (monto <= 0 || plazoMeses <= 0) return 0;
    final t = teaOverride ?? tea;
    final tep = pow(1 + t, 1 / 12).toDouble() - 1;
    if (tep == 0) return monto / plazoMeses;
    final factor = pow(1 + tep, plazoMeses).toDouble();
    return monto * (tep * factor) / (factor - 1);
  }

  static ResultadoSimulacion simular({
    required double monto,
    required int plazoMeses,
  }) {
    final cuota = cuotaFrancesa(monto: monto, plazoMeses: plazoMeses);
    final total = cuota * plazoMeses;
    return ResultadoSimulacion(
      monto: monto,
      plazoMeses: plazoMeses,
      tea: tea,
      cuotaMensual: cuota,
      totalPagar: total,
      costoFinanciero: total - monto,
    );
  }

  static List<CuotaAmortizacion> generarAmortizacion({
    required double monto,
    required int plazoMeses,
  }) {
    final cuota = cuotaFrancesa(monto: monto, plazoMeses: plazoMeses);
    final tep = pow(1 + tea, 1 / 12).toDouble() - 1;
    var saldo = monto;

    return List.generate(plazoMeses, (index) {
      final interes = saldo * tep;
      final capital = cuota - interes;
      saldo = max(0, saldo - capital);
      return CuotaAmortizacion(
        numero: index + 1,
        cuota: cuota,
        interes: interes,
        capital: capital,
        saldo: saldo,
      );
    });
  }
}
