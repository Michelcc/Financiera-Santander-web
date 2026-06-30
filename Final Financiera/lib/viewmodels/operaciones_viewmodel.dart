import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cuenta_ahorro_model.dart';
import '../repositories/cliente_repository.dart';

class OperacionesState {
  const OperacionesState({
    this.cuentas = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.lastOp,
  });

  final List<CuentaAhorroModel> cuentas;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final Map<String, dynamic>? lastOp;
}

class OperacionesNotifier extends StateNotifier<OperacionesState> {
  OperacionesNotifier() : super(const OperacionesState());

  final _repo = ClienteRepository.instance;

  Future<void> load() async {
    state = OperacionesState(
      cuentas: state.cuentas,
      isLoading: true,
    );
    try {
      final cuentas = await _repo.getCuentas();
      state = OperacionesState(cuentas: cuentas);
    } catch (e) {
      state = OperacionesState(error: e.toString());
    }
  }

  Future<bool> ejecutar({
    required String cuentaOrigen,
    String? cuentaDestino,
    required String tipo,
    required double monto,
    String? concepto,
  }) async {
    state = OperacionesState(
      cuentas: state.cuentas,
      isSaving: true,
    );
    try {
      final res = await _repo.registrarOperacion(
        codCuentaOrigen: cuentaOrigen,
        codCuentaDestino: cuentaDestino,
        tipo: tipo,
        monto: monto,
        concepto: concepto,
      );
      await load();
      state = OperacionesState(
        cuentas: state.cuentas,
        lastOp: res,
      );
      return true;
    } catch (e) {
      state = OperacionesState(
        cuentas: state.cuentas,
        error: e.toString(),
      );
      return false;
    }
  }
}

final operacionesProvider =
    StateNotifierProvider<OperacionesNotifier, OperacionesState>((ref) {
  final n = OperacionesNotifier();
  n.load();
  return n;
});
