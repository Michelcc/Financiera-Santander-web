/// Modelo de perfil de cliente autenticado.
/// Mapea la respuesta de GET /cliente/perfil del backend FastAPI.
class PerfilClienteModel {
  const PerfilClienteModel({
    required this.id,
    required this.nombre,
    required this.documento,
    required this.telefono,
    required this.email,
    required this.activo,
    this.numeroCuenta = '',
  });

  final String id;
  final String nombre;
  final String documento;
  final String telefono;
  final String email;
  final bool activo;
  final String numeroCuenta;

  /// Desde respuesta de la API (ClienteOut schema).
  factory PerfilClienteModel.fromApiMap(Map<String, dynamic> map) {
    final nombres = map['nombres'] ?? '';
    final apellidos = map['apellidos'] ?? '';
    return PerfilClienteModel(
      id: map['id']?.toString() ?? '',
      nombre: '$nombres $apellidos'.trim(),
      documento: map['numero_documento']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      activo: true,
    );
  }

  /// Compatibilidad con el mapa antiguo de Supabase (tabla perfiles_cliente).
  factory PerfilClienteModel.fromMap(Map<String, dynamic> map) {
    return PerfilClienteModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      documento: map['documento'] ?? '',
      telefono: map['telefono'] ?? '',
      email: map['email'] ?? '',
      activo: map['activo'] ?? true,
      numeroCuenta: map['numero_cuenta']?.toString() ?? '',
    );
  }

  PerfilClienteModel copyWith({String? nombre, String? telefono}) {
    return PerfilClienteModel(
      id: id,
      nombre: nombre ?? this.nombre,
      documento: documento,
      telefono: telefono ?? this.telefono,
      email: email,
      activo: activo,
      numeroCuenta: numeroCuenta,
    );
  }
}
