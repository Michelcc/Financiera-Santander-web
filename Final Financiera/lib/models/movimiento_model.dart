/// Movimiento desde el backend FastAPI (tabla cr_movimientos).
class MovimientoModel {
  const MovimientoModel({
    required this.id,
    required this.codOperacion,
    required this.monto,
    required this.fechaOperacion,
    this.codCuenta,
    this.tipo,
    this.concepto,
    this.canal,
    this.moneda,
  });

  final String id;
  final String codOperacion;
  final double monto;
  final DateTime fechaOperacion;
  final String? codCuenta;
  final String? tipo;     // DEB / CRE / TRF
  final String? concepto;
  final String? canal;
  final String? moneda;

  bool get esDebito => tipo == 'DEB';
  bool get esCredito => tipo == 'CRE';
  bool get esTransferencia => tipo == 'TRF';

  factory MovimientoModel.fromMap(Map<String, dynamic> map) {
    return MovimientoModel(
      id: map['id']?.toString() ?? '',
      codOperacion: map['cod_operacion']?.toString() ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      fechaOperacion: map['fecha_operacion'] != null
          ? DateTime.tryParse(map['fecha_operacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      codCuenta: map['cod_cuenta']?.toString(),
      tipo: map['tipo']?.toString(),
      concepto: map['concepto']?.toString(),
      canal: map['canal']?.toString(),
      moneda: map['moneda']?.toString() ?? 'PEN',
    );
  }
}
