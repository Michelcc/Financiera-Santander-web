/// Notificación desde el backend FastAPI (tabla notificaciones, destinatario_tipo='cliente').
class NotificacionApiModel {
  const NotificacionApiModel({
    required this.id,
    required this.titulo,
    required this.leida,
    required this.createdAt,
    this.cuerpo,
    this.tipo,
  });

  final String id;
  final String titulo;
  final bool leida;
  final DateTime createdAt;
  final String? cuerpo;
  final String? tipo;

  factory NotificacionApiModel.fromMap(Map<String, dynamic> map) {
    return NotificacionApiModel(
      id: map['id']?.toString() ?? '',
      titulo: map['titulo']?.toString() ?? '',
      leida: map['leida'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      cuerpo: map['cuerpo']?.toString(),
      tipo: map['tipo']?.toString(),
    );
  }
}
