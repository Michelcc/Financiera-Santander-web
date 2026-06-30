/// Crédito desde el backend FastAPI (tabla cr_creditos).
class CreditoApiModel {
  const CreditoApiModel({
    required this.id,
    required this.codCuentaCredito,
    required this.montoDesembolsado,
    required this.saldoCapital,
    required this.saldoTotal,
    required this.diasMora,
    required this.estado,
    this.producto,
    this.calificacionInterna,
    this.fechaDesembolso,
    this.tea,
    this.cuotasTotal,
    this.cuotasPagadas,
  });

  final String id;
  final String codCuentaCredito;
  final double montoDesembolsado;
  final double saldoCapital;
  final double saldoTotal;
  final int diasMora;
  final String estado;
  final String? producto;
  final String? calificacionInterna;
  final DateTime? fechaDesembolso;
  final double? tea;
  final int? cuotasTotal;
  final int? cuotasPagadas;

  bool get alDia => diasMora == 0;
  bool get enMora => diasMora > 0;

  factory CreditoApiModel.fromMap(Map<String, dynamic> map) {
    return CreditoApiModel(
      id: map['id']?.toString() ?? '',
      codCuentaCredito: map['cod_cuenta_credito']?.toString() ?? '',
      montoDesembolsado: (map['monto_desembolsado'] as num?)?.toDouble() ?? 0,
      saldoCapital: (map['saldo_capital'] as num?)?.toDouble() ?? 0,
      saldoTotal: (map['saldo_total'] as num?)?.toDouble() ?? 0,
      diasMora: (map['dias_mora'] as num?)?.toInt() ?? 0,
      estado: map['estado']?.toString() ?? 'vigente',
      producto: map['producto']?.toString(),
      calificacionInterna: map['calificacion_interna']?.toString(),
      fechaDesembolso: map['fecha_desembolso'] != null
          ? DateTime.tryParse(map['fecha_desembolso'].toString())
          : null,
      tea: (map['tea'] as num?)?.toDouble(),
      cuotasTotal: (map['cuotas_total'] as num?)?.toInt(),
      cuotasPagadas: (map['cuotas_pagadas'] as num?)?.toInt(),
    );
  }
}
