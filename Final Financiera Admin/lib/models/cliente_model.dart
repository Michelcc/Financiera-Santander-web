import 'dart:convert';

enum SegmentoCliente {
  premier,
  estandar,
  basico,
  noAplica;

  static SegmentoCliente fromScore(int score) {
    if (score >= 750) return SegmentoCliente.premier;
    if (score >= 550) return SegmentoCliente.estandar;
    if (score >= 350) return SegmentoCliente.basico;
    return SegmentoCliente.noAplica;
  }

  static SegmentoCliente fromText(String? value, int score) {
    final normalized = (value ?? '').trim().toUpperCase();
    return switch (normalized) {
      'PREMIER' => SegmentoCliente.premier,
      'ESTÁNDAR' || 'ESTANDAR' => SegmentoCliente.estandar,
      'BÁSICO' || 'BASICO' => SegmentoCliente.basico,
      'NO_APLICA' || 'NO APLICA' => SegmentoCliente.noAplica,
      _ => fromScore(score),
    };
  }

  String get label => switch (this) {
        SegmentoCliente.premier => 'PREMIER',
        SegmentoCliente.estandar => 'ESTÁNDAR',
        SegmentoCliente.basico => 'BÁSICO',
        SegmentoCliente.noAplica => 'NO APLICA',
      };
}

class ClienteModel {
  const ClienteModel({
    required this.id,
    required this.documento,
    required this.nombre,
    required this.telefono,
    required this.negocioNombre,
    required this.negocioTipo,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.tipoGestion,
    required this.prioridad,
    required this.scoreTransaccional,
    this.scoreCampo = 0,
    this.scoreFinal = 0,
    this.hipotesisCredito = 0,
    this.segmento = 'ESTANDAR',
    required this.deudaTotal,
    required this.moraDias,
    required this.ultimoPagoFecha,
    required this.montoPreaprobado,
    required this.plazoPreaprobado,
    required this.tasaPreaprobada,
    required this.historialPagos,
  });

  final String id;
  final String documento;
  final String nombre;
  final String telefono;
  final String negocioNombre;
  final String negocioTipo;
  final String direccion;
  final double latitud;
  final double longitud;
  final String tipoGestion; // Renovación, Mora, Ampliación
  final int prioridad;      // 1 (máxima) a 4 (mínima)
  final int scoreTransaccional;
  final int scoreCampo;
  final int scoreFinal;
  final double hipotesisCredito;
  final String segmento;
  final double deudaTotal;
  final int moraDias;
  final String ultimoPagoFecha;
  final double montoPreaprobado;
  final int plazoPreaprobado;
  final double tasaPreaprobada;
  final String historialPagos; // JSON string of double array

  List<double> get historialPagosList {
    try {
      final decoded = jsonDecode(historialPagos) as List<dynamic>;
      return decoded.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return List.filled(12, 0.0);
    }
  }

  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    return ClienteModel(
      id: map['id'] ?? '',
      documento: '${map['documento'] ?? ''}',
      nombre: '${map['nombre'] ?? ''}',
      telefono: '${map['telefono'] ?? ''}',
      negocioNombre: '${map['negocio_nombre'] ?? ''}',
      negocioTipo: map['negocio_tipo'] ?? '',
      direccion: map['direccion'] ?? '',
      latitud: (map['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (map['longitud'] as num?)?.toDouble() ?? 0.0,
      tipoGestion: '${map['tipo_gestion'] ?? 'Renovacion'}',
      prioridad: (map['prioridad'] as num?)?.toInt() ?? 3,
      scoreTransaccional: (map['score_transaccional'] as num?)?.toInt() ?? 500,
      scoreCampo: (map['score_campo'] as num?)?.toInt() ?? 0,
      scoreFinal: (map['score_final'] as num?)?.toInt() ??
          ((map['score_transaccional'] as num?)?.toInt() ?? 500) +
              ((map['score_campo'] as num?)?.toInt() ?? 0),
      hipotesisCredito: (map['hipotesis_credito'] as num?)?.toDouble() ?? 0,
      segmento: map['segmento'] ?? 'ESTANDAR',
      deudaTotal: (map['deuda_total'] as num?)?.toDouble() ?? 0.0,
      moraDias: (map['mora_dias'] as num?)?.toInt() ?? 0,
      ultimoPagoFecha: map['ultimo_pago_fecha'] ?? '',
      montoPreaprobado: (map['monto_preaprobado'] as num?)?.toDouble() ?? 0.0,
      plazoPreaprobado: (map['plazo_preaprobado'] as num?)?.toInt() ?? 6,
      tasaPreaprobada: (map['tasa_preaprobada'] as num?)?.toDouble() ?? 18.0,
      historialPagos: _historialToString(map['historial_pagos']),
    );
  }

  static String _historialToString(dynamic value) {
    if (value == null) return '[]';
    if (value is String) return value;
    return jsonEncode(value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documento': documento,
      'nombre': nombre,
      'telefono': telefono,
      'negocio_nombre': negocioNombre,
      'negocio_tipo': negocioTipo,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'tipo_gestion': tipoGestion,
      'prioridad': prioridad,
      'score_transaccional': scoreTransaccional,
      'score_campo': scoreCampo,
      'score_final': scoreFinal,
      'hipotesis_credito': hipotesisCredito,
      'segmento': segmento,
      'deuda_total': deudaTotal,
      'mora_dias': moraDias,
      'ultimo_pago_fecha': ultimoPagoFecha,
      'monto_preaprobado': montoPreaprobado,
      'plazo_preaprobado': plazoPreaprobado,
      'tasa_preaprobada': tasaPreaprobada,
      'historial_pagos': historialPagos,
    };
  }
}
