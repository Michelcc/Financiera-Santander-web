import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/cartera_item.dart';
import '../models/cartera_status.dart';
import '../repositories/cartera_repository.dart';
import '../services/route_optimization_service.dart';
import 'auth_viewmodel.dart';

class CarteraState {
  CarteraState({
    this.status = CarteraStatus.idle,
    this.clientes = const [],
    this.visitasHoy = const {},
    this.userLat = -12.1200,
    this.userLng = -77.0300,
    this.isRouteOptimized = false,
    this.syncProgressText = '',
    this.isOffline = false,
    this.fromCache = false,
    this.error,
  });

  final CarteraStatus status;
  final List<CarteraItem> clientes;
  final Map<String, String> visitasHoy;
  final double userLat;
  final double userLng;
  final bool isRouteOptimized;
  final String syncProgressText;
  final bool isOffline;
  final bool fromCache;
  final String? error;

  bool get isLoading => status == CarteraStatus.loading;

  CarteraState copyWith({
    CarteraStatus? status,
    List<CarteraItem>? clientes,
    Map<String, String>? visitasHoy,
    double? userLat,
    double? userLng,
    bool? isRouteOptimized,
    String? syncProgressText,
    bool? isOffline,
    bool? fromCache,
    String? error,
    bool clearError = false,
  }) {
    return CarteraState(
      status: status ?? this.status,
      clientes: clientes ?? this.clientes,
      visitasHoy: visitasHoy ?? this.visitasHoy,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      isRouteOptimized: isRouteOptimized ?? this.isRouteOptimized,
      syncProgressText: syncProgressText ?? this.syncProgressText,
      isOffline: isOffline ?? this.isOffline,
      fromCache: fromCache ?? this.fromCache,
      error: clearError ? null : (error ?? this.error),
    );
  }

  double get progressPercentage {
    if (clientes.isEmpty) return 0.0;
    return visitasHoy.length / clientes.length;
  }
}

class CarteraNotifier extends StateNotifier<CarteraState> {
  CarteraNotifier(this._repo) : super(CarteraState()) {
    loadPortfolio();
  }

  final CarteraRepository _repo;

  Future<void> syncFromServer() async {
    state = state.copyWith(
      status: CarteraStatus.loading,
      syncProgressText: 'Sincronizando...',
    );
    final result = await _repo.syncFromServer();
    await _applyLoadResult(result);
    state = state.copyWith(
      syncProgressText: '${state.clientes.length} clientes',
    );
  }

  Future<void> loadPortfolio() async {
    state = state.copyWith(status: CarteraStatus.loading);

    final coords = await _resolveUserLocation();

    try {
      final result = await _repo.obtenerCartera();
      state = state.copyWith(
        userLat: coords.$1,
        userLng: coords.$2,
      );
      await _applyLoadResult(result);
    } catch (e) {
      state = state.copyWith(
        status: CarteraStatus.error,
        error: e.toString(),
        userLat: coords.$1,
        userLng: coords.$2,
      );
    }
  }

  Future<void> _applyLoadResult(CarteraLoadResult result) async {
    state = state.copyWith(
      status: CarteraStatus.ready,
      clientes: result.items,
      visitasHoy: result.visitasHoy,
      isOffline: result.isOffline,
      fromCache: result.fromCache,
      error: result.error,
      clearError: result.error == null && result.items.isNotEmpty,
      syncProgressText: result.items.isEmpty
          ? (result.error ?? 'Sin clientes — toque ↻ para sincronizar')
          : '${result.items.length} clientes',
    );
  }

  Future<(double, double)> _resolveUserLocation() async {
    double lat = -12.1221;
    double lng = -77.0298;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}
    return (lat, lng);
  }

  void reorderClientsById(
    List<CarteraItem> visibleClients,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 ||
        oldIndex >= visibleClients.length ||
        newIndex < 0 ||
        newIndex >= visibleClients.length) {
      return;
    }

    final movedId = visibleClients[oldIndex].id;
    final targetId = visibleClients[newIndex].id;

    final list = List<CarteraItem>.from(state.clientes);
    final oldFull = list.indexWhere((c) => c.id == movedId);
    final newFull = list.indexWhere((c) => c.id == targetId);
    if (oldFull < 0 || newFull < 0) return;

    final item = list.removeAt(oldFull);
    list.insert(newFull, item);
    state = state.copyWith(clientes: list, isRouteOptimized: false);
  }

  void optimizeRoute() {
    state = state.copyWith(status: CarteraStatus.loading);
    final optimized = RouteOptimizationService.optimize(
      clients: state.clientes,
      startLat: state.userLat,
      startLng: state.userLng,
    );
    state = state.copyWith(
      clientes: optimized,
      isRouteOptimized: true,
      status: CarteraStatus.ready,
    );
  }

  Future<void> logVisit({
    required String clientId,
    required String result,
    required String observation,
  }) async {
    final visitId = 'vis_${clientId}_${DateTime.now().millisecondsSinceEpoch}';

    double lat = state.userLat;
    double lng = state.userLng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    final visitData = {
      'id': visitId,
      'cliente_id': clientId,
      'resultado': result,
      'observacion': observation,
      'latitud': lat,
      'longitud': lng,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };

    await _repo.marcarVisita(visitData: visitData);

    final updatedVisits = Map<String, String>.from(state.visitasHoy);
    updatedVisits[clientId] = result;
    state = state.copyWith(visitasHoy: updatedVisits);
  }

  Future<void> updateBusinessCoords(String clientId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      await _repo.actualizarCoordenadas(
        clientId,
        pos.latitude,
        pos.longitude,
      );
      await loadPortfolio();
    } catch (_) {}
  }
}

final carteraProvider =
    StateNotifierProvider<CarteraNotifier, CarteraState>((ref) {
  return CarteraNotifier(ref.watch(carteraRepositoryProvider));
});
