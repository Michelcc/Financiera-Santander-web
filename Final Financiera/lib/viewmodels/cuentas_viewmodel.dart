import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cuenta_ahorro_model.dart';
import '../models/movimiento_model.dart';
import '../repositories/cliente_repository.dart';

class CuentasState {
  const CuentasState({
    this.cuentas = const [],
    this.movimientos = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CuentaAhorroModel> cuentas;
  final List<MovimientoModel> movimientos;
  final bool isLoading;
  final String? error;

  double get saldoTotal =>
      cuentas.fold(0, (sum, c) => sum + c.saldoCapital);
}

class CuentasNotifier extends StateNotifier<CuentasState> {
  CuentasNotifier() : super(const CuentasState());

  final _repo = ClienteRepository.instance;

  Future<void> load() async {
    state = const CuentasState(isLoading: true);
    try {
      final cuentas = await _repo.getCuentas();
      final movimientos = await _repo.getMovimientos(limit: 15);
      state = CuentasState(cuentas: cuentas, movimientos: movimientos);
    } catch (e) {
      state = CuentasState(error: e.toString());
    }
  }
}

final cuentasProvider =
    StateNotifierProvider<CuentasNotifier, CuentasState>((ref) {
  final n = CuentasNotifier();
  n.load();
  return n;
});
