class NotificacionModel {
  const NotificacionModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    this.leida = false,
    this.createdAt,
  });

  final String id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime? createdAt;

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    return NotificacionModel(
      id: map['id'] ?? '',
      tipo: map['tipo'] ?? 'info',
      titulo: map['titulo'] ?? '',
      mensaje: map['mensaje'] ?? '',
      leida: map['leida'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
