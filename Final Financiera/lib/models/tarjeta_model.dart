/// Tarjeta de crédito desde el backend FastAPI (tabla tarjetas).
class TarjetaModel {
  const TarjetaModel({
    required this.id,
    required this.numeroEnmascarado,
    required this.estado,
    this.marca,
    this.lineaCredito,
    this.saldoUtilizado,
    this.fechaCorte,
    this.fechaPago,
  });

  final String id;
  final String numeroEnmascarado;
  final String estado;
  final String? marca;
  final double? lineaCredito;
  final double? saldoUtilizado;
  final DateTime? fechaCorte;
  final DateTime? fechaPago;

  double get disponible => (lineaCredito ?? 0) - (saldoUtilizado ?? 0);
  double get porcentajeUso =>
      lineaCredito != null && lineaCredito! > 0
          ? ((saldoUtilizado ?? 0) / lineaCredito!) * 100
          : 0;

  factory TarjetaModel.fromMap(Map<String, dynamic> map) {
    return TarjetaModel(
      id: map['id']?.toString() ?? '',
      numeroEnmascarado: map['numero_enmascarado']?.toString() ?? '',
      estado: map['estado']?.toString() ?? 'activa',
      marca: map['marca']?.toString(),
      lineaCredito: (map['linea_credito'] as num?)?.toDouble(),
      saldoUtilizado: (map['saldo_utilizado'] as num?)?.toDouble(),
      fechaCorte: map['fecha_corte'] != null
          ? DateTime.tryParse(map['fecha_corte'].toString())
          : null,
      fechaPago: map['fecha_pago'] != null
          ? DateTime.tryParse(map['fecha_pago'].toString())
          : null,
    );
  }
}
