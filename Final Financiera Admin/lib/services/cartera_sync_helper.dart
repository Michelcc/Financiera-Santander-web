/// Convierte prospecto o perfil a fila de cartera local/remota.
class CarteraSyncHelper {
  static Map<String, dynamic> fromProspect(Map<String, dynamic> p) {
    final doc = p['documento']?.toString() ?? '';
    return {
      'id': 'cli_$doc',
      'documento': doc,
      'nombre': p['nombre'] ?? '',
      'telefono': p['telefono'] ?? '',
      'negocio_nombre': p['negocio_nombre'] ?? 'Por definir',
      'negocio_tipo': 'Comercio',
      'direccion': '',
      'latitud': (p['latitud'] as num?)?.toDouble() ?? -12.12,
      'longitud': (p['longitud'] as num?)?.toDouble() ?? -77.03,
      'tipo_gestion': 'Nueva Solicitud',
      'prioridad': 3,
      'score_transaccional': 500,
      'score_campo': 0,
      'score_final': 500,
      'hipotesis_credito': 0.0,
      'segmento': 'ESTANDAR',
      'deuda_total': 0.0,
      'mora_dias': 0,
      'ultimo_pago_fecha': '',
      'monto_preaprobado': 0.0,
      'plazo_preaprobado': 6,
      'tasa_preaprobada': 18.0,
      'historial_pagos': '[]',
    };
  }

  static Map<String, dynamic> fromPerfil({
    required String documento,
    required String nombre,
    String? telefono,
    String? negocioNombre,
  }) {
    return fromProspect({
      'documento': documento,
      'nombre': nombre,
      'telefono': telefono ?? '',
      'negocio_nombre': negocioNombre ?? 'Registro app cliente',
    });
  }
}
