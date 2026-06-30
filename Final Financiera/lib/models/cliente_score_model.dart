class ClienteScoreModel {
  const ClienteScoreModel({
    required this.id,
    required this.documento,
    required this.nombre,
    this.scoreTransaccional = 0,
    this.scoreCampo = 0,
    this.scoreFinal = 0,
    this.hipotesisCredito = 0,
    this.segmento = 'ESTANDAR',
    this.deudaTotal = 0,
    this.moraDias = 0,
    this.proximaCuotaMonto = 0,
    this.proximaCuotaFecha,
    this.estadoCredito = 'AL_DIA',
    this.asesorId,
  });

  final String id;
  final String documento;
  final String nombre;
  final int scoreTransaccional;
  final int scoreCampo;
  final int scoreFinal;
  final double hipotesisCredito;
  final String segmento;
  final double deudaTotal;
  final int moraDias;
  final double proximaCuotaMonto;
  final DateTime? proximaCuotaFecha;
  final String estadoCredito;
  final String? asesorId;

  bool get alDia => moraDias == 0 && estadoCredito == 'AL_DIA';

  factory ClienteScoreModel.fromMap(Map<String, dynamic> map) {
    return ClienteScoreModel(
      id: map['id'] ?? '',
      documento: map['documento'] ?? '',
      nombre: map['nombre'] ?? '',
      scoreTransaccional: (map['score_transaccional'] as num?)?.toInt() ?? 0,
      scoreCampo: (map['score_campo'] as num?)?.toInt() ?? 0,
      scoreFinal: (map['score_final'] as num?)?.toInt() ??
          ((map['score_transaccional'] as num?)?.toInt() ?? 0) +
              ((map['score_campo'] as num?)?.toInt() ?? 0),
      hipotesisCredito: (map['hipotesis_credito'] as num?)?.toDouble() ??
          (((map['score_final'] as num?)?.toInt() ?? 500) * 100).toDouble(),
      segmento: map['segmento'] ?? 'ESTANDAR',
      deudaTotal: (map['deuda_total'] as num?)?.toDouble() ?? 0,
      moraDias: (map['mora_dias'] as num?)?.toInt() ?? 0,
      proximaCuotaMonto:
          (map['proxima_cuota_monto'] as num?)?.toDouble() ?? 0,
      proximaCuotaFecha: map['proxima_cuota_fecha'] != null
          ? DateTime.tryParse(map['proxima_cuota_fecha'].toString())
          : null,
      estadoCredito: map['estado_credito'] ?? 'AL_DIA',
      asesorId: map['asesor_asignado_id'] ?? map['asesor_id'],
    );
  }

  factory ClienteScoreModel.demo(String nombre, String documento) {
    return ClienteScoreModel(
      id: 'demo',
      documento: documento,
      nombre: nombre,
      scoreTransaccional: 700,
      scoreCampo: 50,
      scoreFinal: 750,
      hipotesisCredito: 75000,
      segmento: 'PREMIER',
      deudaTotal: 15000,
      moraDias: 0,
      proximaCuotaMonto: 450,
      proximaCuotaFecha: DateTime(2026, 6, 15),
      estadoCredito: 'AL_DIA',
    );
  }

  ClienteScoreModel copyWith({
    int? scoreTransaccional,
    int? scoreCampo,
    int? scoreFinal,
    double? hipotesisCredito,
    String? segmento,
  }) {
    return ClienteScoreModel(
      id: id,
      documento: documento,
      nombre: nombre,
      scoreTransaccional: scoreTransaccional ?? this.scoreTransaccional,
      scoreCampo: scoreCampo ?? this.scoreCampo,
      scoreFinal: scoreFinal ?? this.scoreFinal,
      hipotesisCredito: hipotesisCredito ?? this.hipotesisCredito,
      segmento: segmento ?? this.segmento,
      deudaTotal: deudaTotal,
      moraDias: moraDias,
      proximaCuotaMonto: proximaCuotaMonto,
      proximaCuotaFecha: proximaCuotaFecha,
      estadoCredito: estadoCredito,
      asesorId: asesorId,
    );
  }
}
