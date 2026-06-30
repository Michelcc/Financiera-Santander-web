import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notificacion_model.dart';
import '../repositories/cliente_repository.dart';
import '../services/cliente_supabase_service.dart';

class NotificacionesState {
  const NotificacionesState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<NotificacionModel> items;
  final bool isLoading;
  final String? error;

  int get noLeidas => items.where((n) => !n.leida).length;
}

class NotificacionesNotifier extends StateNotifier<NotificacionesState> {
  NotificacionesNotifier() : super(const NotificacionesState()) {
    load();
  }

  final _repo = ClienteRepository.instance;
  RealtimeChannel? _channel;

  Future<void> load() async {
    state = const NotificacionesState(isLoading: true);
    try {
      final items = await _repo.getNotificaciones();
      state = NotificacionesState(items: items);
      _channel ??= ClienteSupabaseService.instance
          .subscribeToNotificaciones(() => load());
    } catch (e) {
      state = NotificacionesState(error: e.toString());
    }
  }

  Future<void> marcarLeida(String id) async {
    await _repo.marcarNotificacionLeida(id);
    await load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificacionesProvider =
    StateNotifierProvider<NotificacionesNotifier, NotificacionesState>(
  (ref) => NotificacionesNotifier(),
);
