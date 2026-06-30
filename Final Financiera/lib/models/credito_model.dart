class CreditoModel {
  const CreditoModel({
    required this.id,
    required this.monto,
    required this.plazoMeses,
    required this.tea,
    required this.cuotaMensual,
    required this.saldoPendiente,
    required this.estado,
    this.fechaDesembolso,
    this.fechaVencimiento,
    this.diasMora = 0,
    this.pagos = const [],
  });

  final String id;
  final double monto;
  final int plazoMeses;
  final double tea;
  final double cuotaMensual;
  final double saldoPendiente;
  final String estado;
  final DateTime? fechaDesembolso;
  final DateTime? fechaVencimiento;
  final int diasMora;
  final List<PagoCreditoModel> pagos;

  factory CreditoModel.fromMap(Map<String, dynamic> map) {
    return CreditoModel(
      id: map['id'] ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      plazoMeses: (map['plazo_meses'] as num?)?.toInt() ?? 12,
      tea: (map['tea'] as num?)?.toDouble() ?? 60,
      cuotaMensual: (map['cuota_mensual'] as num?)?.toDouble() ?? 0,
      saldoPendiente: (map['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      estado: map['estado'] ?? 'VIGENTE',
      fechaDesembolso: map['fecha_desembolso'] != null
          ? DateTime.tryParse(map['fecha_desembolso'].toString())
          : null,
      fechaVencimiento: map['fecha_vencimiento'] != null
          ? DateTime.tryParse(map['fecha_vencimiento'].toString())
          : null,
      diasMora: (map['dias_mora'] as num?)?.toInt() ?? 0,
    );
  }
}

class PagoCreditoModel {
  const PagoCreditoModel({
    required this.numeroCuota,
    required this.monto,
    required this.fechaVencimiento,
    this.fechaPago,
    this.diasMora = 0,
    this.estado = 'PENDIENTE',
  });

  final int numeroCuota;
  final double monto;
  final DateTime fechaVencimiento;
  final DateTime? fechaPago;
  final int diasMora;
  final String estado;

  bool get pagadoATiempo =>
      estado == 'PAGADO' && (fechaPago != null && diasMora == 0);

  bool get pagadoConMora => estado == 'PAGADO' && diasMora > 0;

  factory PagoCreditoModel.fromMap(Map<String, dynamic> map) {
    return PagoCreditoModel(
      numeroCuota: (map['numero_cuota'] as num?)?.toInt() ?? 0,
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      fechaVencimiento:
          DateTime.tryParse(map['fecha_vencimiento'].toString()) ??
              DateTime.now(),
      fechaPago: map['fecha_pago'] != null
          ? DateTime.tryParse(map['fecha_pago'].toString())
          : null,
      diasMora: (map['dias_mora'] as num?)?.toInt() ?? 0,
      estado: map['estado'] ?? 'PENDIENTE',
    );
  }
}
