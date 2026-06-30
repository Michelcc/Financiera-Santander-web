import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_score_model.dart';
import '../services/cliente_supabase_service.dart';

class DashboardState {
  const DashboardState({
    this.scores,
    this.isLoading = false,
    this.error,
  });

  final ClienteScoreModel? scores;
  final bool isLoading;
  final String? error;

  DashboardState copyWith({
    ClienteScoreModel? scores,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      scores: scores ?? this.scores,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState()) {
    load();
  }

  final _service = ClienteSupabaseService.instance;
  RealtimeChannel? _channel;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final scores = await _service.getClienteScores();
      state = DashboardState(scores: scores, isLoading: false);
      _subscribeRealtime(scores?.documento);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeRealtime(String? documento) {
    if (documento == null) return;
    _channel?.unsubscribe();
    _channel = _service.subscribeToScores(documento, (updated) {
      state = state.copyWith(scores: updated);
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
