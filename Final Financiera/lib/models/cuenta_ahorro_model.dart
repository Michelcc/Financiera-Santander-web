/// Cuenta de ahorro desde el backend FastAPI (tabla cr_cuentas_ahorro).
class CuentaAhorroModel {
  const CuentaAhorroModel({
    required this.id,
    required this.codCuentaAhorro,
    required this.saldoCapital,
    required this.estado,
    this.tipoCuenta,
    this.moneda,
    this.saldoInteres,
    this.tea,
  });

  final String id;
  final String codCuentaAhorro;
  final double saldoCapital;
  final String estado;
  final String? tipoCuenta;
  final String? moneda;
  final double? saldoInteres;
  final double? tea;

  factory CuentaAhorroModel.fromMap(Map<String, dynamic> map) {
    return CuentaAhorroModel(
      id: map['id']?.toString() ?? '',
      codCuentaAhorro: map['cod_cuenta_ahorro']?.toString() ?? '',
      saldoCapital: (map['saldo_capital'] as num?)?.toDouble() ?? 0,
      estado: map['estado']?.toString() ?? 'activa',
      tipoCuenta: map['tipo_cuenta']?.toString(),
      moneda: map['moneda']?.toString() ?? 'PEN',
      saldoInteres: (map['saldo_interes'] as num?)?.toDouble(),
      tea: (map['tea'] as num?)?.toDouble(),
    );
  }
}
