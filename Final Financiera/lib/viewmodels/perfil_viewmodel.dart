import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/perfil_cliente_model.dart';
import '../repositories/cliente_repository.dart';

class PerfilState {
  const PerfilState({
    this.perfil,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.saved = false,
  });

  final PerfilClienteModel? perfil;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool saved;
}

class PerfilNotifier extends StateNotifier<PerfilState> {
  PerfilNotifier() : super(const PerfilState()) {
    load();
  }

  final _repo = ClienteRepository.instance;

  Future<void> load() async {
    state = const PerfilState(isLoading: true);
    try {
      final perfil = await _repo.getPerfil();
      state = PerfilState(perfil: perfil);
    } catch (e) {
      state = PerfilState(error: e.toString());
    }
  }

  Future<void> guardar({required String nombre, required String telefono}) async {
    state = PerfilState(perfil: state.perfil, isSaving: true);
    try {
      await _repo.actualizarPerfil(nombre: nombre, telefono: telefono);
      await load();
      state = PerfilState(perfil: state.perfil, saved: true);
    } catch (e) {
      state = PerfilState(perfil: state.perfil, error: e.toString());
    }
  }
}

final perfilProvider =
    StateNotifierProvider<PerfilNotifier, PerfilState>((ref) => PerfilNotifier());
