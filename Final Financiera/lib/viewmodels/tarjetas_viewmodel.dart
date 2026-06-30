import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tarjeta_model.dart';
import '../repositories/cliente_repository.dart';

class TarjetasState {
  const TarjetasState({this.tarjetas = const [], this.isLoading = false, this.error});
  final List<TarjetaModel> tarjetas;
  final bool isLoading;
  final String? error;
}

class TarjetasNotifier extends StateNotifier<TarjetasState> {
  TarjetasNotifier() : super(const TarjetasState());

  final _repo = ClienteRepository.instance;

  Future<void> load() async {
    state = const TarjetasState(isLoading: true);
    try {
      final tarjetas = await _repo.getTarjetas();
      state = TarjetasState(tarjetas: tarjetas);
    } catch (e) {
      state = TarjetasState(error: e.toString());
    }
  }
}

final tarjetasProvider =
    StateNotifierProvider<TarjetasNotifier, TarjetasState>((ref) {
  final n = TarjetasNotifier();
  n.load();
  return n;
});
