/// Modelo de perfil de cliente autenticado.
/// Corresponde a la tabla [perfiles_cliente] en Supabase.
/// Es distinto de [ClienteModel], que representa la cartera de un asesor.
class PerfilClienteModel {
  const PerfilClienteModel({
    required this.id,
    required this.nombre,
    required this.documento,
    required this.telefono,
    required this.email,
    required this.numeroCuenta,
    required this.activo,
    required this.createdAt,
  });

  final String id;
  final String nombre;
  final String documento;   // DNI del cliente
  final String telefono;
  final String email;
  final String numeroCuenta; // Formato: SCF-XXXXXXXX
  final bool activo;
  final String createdAt;

  factory PerfilClienteModel.fromMap(Map<String, dynamic> map) {
    return PerfilClienteModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      documento: map['documento'] ?? '',
      telefono: map['telefono'] ?? '',
      email: map['email'] ?? '',
      numeroCuenta: map['numero_cuenta'] ?? '',
      activo: map['activo'] ?? true,
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'documento': documento,
      'telefono': telefono,
      'email': email,
      'numero_cuenta': numeroCuenta,
      'activo': activo,
      'created_at': createdAt,
    };
  }

  PerfilClienteModel copyWith({
    String? nombre,
    String? telefono,
  }) {
    return PerfilClienteModel(
      id: id,
      nombre: nombre ?? this.nombre,
      documento: documento,
      telefono: telefono ?? this.telefono,
      email: email,
      numeroCuenta: numeroCuenta,
      activo: activo,
      createdAt: createdAt,
    );
  }
}
