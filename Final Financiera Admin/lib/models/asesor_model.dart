/// Perfil del asesor autenticado (diagrama de clases UML).
class AsesorModel {
  const AsesorModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.rol,
    this.sucursal,
    this.agenciaId,
  });

  final String id;
  final String codigo;
  final String nombre;
  final String rol;
  final String? sucursal;
  final String? agenciaId;

  factory AsesorModel.fromMap(Map<String, dynamic> map) {
    return AsesorModel(
      id: map['id']?.toString() ?? '',
      codigo: (map['codigo'] ?? map['code'] ?? '').toString().toUpperCase(),
      nombre: map['nombre'] ?? map['name'] ?? 'Asesor',
      rol: map['rol'] ?? map['role'] ?? 'Operador',
      sucursal: map['sucursal']?.toString(),
      agenciaId: map['agencia_id']?.toString(),
    );
  }

  factory AsesorModel.fromApiMap(Map<String, dynamic> map) {
    return AsesorModel(
      id: map['id']?.toString() ?? '',
      codigo: (map['cod_empleado'] ?? map['codigo'] ?? '').toString().toUpperCase(),
      nombre: '${map['nombres'] ?? ''} ${map['apellidos'] ?? ''}'.trim(),
      rol: map['perfil'] ?? map['rol'] ?? 'Operador',
      sucursal: map['sucursal']?.toString(),
      agenciaId: map['agencia_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'rol': rol,
        'sucursal': sucursal,
        'agencia_id': agenciaId,
      };
}

enum PerfilAsesor {
  operador('Operador'),
  superOperador('Super Operador'),
  supervisor('Supervisor'),
  administrador('Administrador');

  const PerfilAsesor(this.label);
  final String label;

  static PerfilAsesor fromLabel(String value) {
    return PerfilAsesor.values.firstWhere(
      (p) => p.label.toLowerCase() == value.toLowerCase(),
      orElse: () => PerfilAsesor.operador,
    );
  }
}
