class SolicitudModel {
  const SolicitudModel({
    required this.id,
    required this.estado,
    required this.monto,
    required this.plazo,
    this.cuotaMensual = 0,
    this.montoAprobado = 0,
    this.motivoRechazo,
    this.expedienteNumero,
    this.createdAt,
    this.timeline = const [],
  });

  final String id;
  final String estado;
  final double monto;
  final int plazo;
  final double cuotaMensual;
  final double montoAprobado;
  final String? motivoRechazo;
  final String? expedienteNumero;
  final DateTime? createdAt;
  final List<SolicitudTimelineItem> timeline;

  String get categoria {
    final e = estado.toUpperCase();
    if (e.contains('APROB')) return 'Aprobadas';
    if (e.contains('RECHAZ')) return 'Rechazadas';
    if (e.contains('DESEMBOLS')) return 'Desembolsadas';
    return 'Enviadas';
  }

  factory SolicitudModel.fromMap(Map<String, dynamic> map) {
    final condiciones = map['condiciones'];
    final monto = condiciones is Map
        ? (condiciones['monto'] as num?)?.toDouble() ?? 0
        : (map['monto_aprobado'] as num?)?.toDouble() ?? 0;
    final plazo = condiciones is Map
        ? (condiciones['plazo'] as num?)?.toInt() ?? 6
        : (map['plazo_aprobado'] as num?)?.toInt() ?? 6;

    List<SolicitudTimelineItem> timeline = [];
    final rawTimeline = map['timeline'];
    if (rawTimeline is List) {
      timeline = rawTimeline
          .map((e) => SolicitudTimelineItem.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return SolicitudModel(
      id: map['id'] ?? '',
      estado: map['estado'] ?? 'Pendiente',
      monto: monto,
      plazo: plazo,
      cuotaMensual: (map['cuota_mensual'] as num?)?.toDouble() ?? 0,
      montoAprobado: (map['monto_aprobado'] as num?)?.toDouble() ?? 0,
      motivoRechazo: map['motivo_rechazo'],
      expedienteNumero: map['expediente_numero'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      timeline: timeline,
    );
  }
}

class SolicitudTimelineItem {
  const SolicitudTimelineItem({
    required this.estado,
    required this.fecha,
    this.descripcion,
  });

  final String estado;
  final DateTime fecha;
  final String? descripcion;

  factory SolicitudTimelineItem.fromMap(Map<String, dynamic> map) {
    return SolicitudTimelineItem(
      estado: map['estado'] ?? '',
      fecha: DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now(),
      descripcion: map['descripcion'],
    );
  }
}
