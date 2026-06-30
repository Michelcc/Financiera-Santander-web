import 'dart:math';
import '../models/cliente_model.dart';

class RouteOptimizationService {
  // Nearest Neighbor routing algorithm
  static List<ClienteModel> optimize({
    required List<ClienteModel> clients,
    required double startLat,
    required double startLng,
  }) {
    if (clients.isEmpty) return [];

    final List<ClienteModel> unvisited = List.from(clients);
    final List<ClienteModel> optimized = [];

    double currentLat = startLat;
    double currentLng = startLng;

    while (unvisited.isNotEmpty) {
      int nearestIndex = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final client = unvisited[i];
        final dist = _calculateDistance(currentLat, currentLng, client.latitud, client.longitud);
        if (dist < minDistance) {
          minDistance = dist;
          nearestIndex = i;
        }
      }

      final nearestClient = unvisited.removeAt(nearestIndex);
      optimized.add(nearestClient);
      
      currentLat = nearestClient.latitud;
      currentLng = nearestClient.longitud;
    }

    return optimized;
  }

  // Haversine distance formula (in km)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
        
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
