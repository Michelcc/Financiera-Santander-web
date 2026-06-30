import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/cliente_model.dart';
import '../../viewmodels/cartera_viewmodel.dart';

class RutaScreen extends ConsumerStatefulWidget {
  const RutaScreen({super.key});

  @override
  ConsumerState<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends ConsumerState<RutaScreen> {
  ClienteModel? _selectedClient;

  Future<void> _openExternalMap(ClienteModel client, String platform) async {
    final lat = client.latitud;
    final lng = client.longitud;
    
    Uri uri;
    if (platform == 'waze') {
      uri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    } else {
      // Google Maps
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        // Fallback to browser Google Maps
        final fallback = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el mapa: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(carteraProvider);
    final notifier = ref.read(carteraProvider.notifier);

    // Default to the first client in list if none selected
    final activeClient = _selectedClient ?? (state.clientes.isNotEmpty ? state.clientes.first : null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text(
          'Mapa de Planificación de Ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Geofence status and user GPS panel
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Color(0xFFEC0000)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mi Ubicación (GPS Campo)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      Text(
                        'Lat: ${state.userLat.toStringAsFixed(5)}, Lng: ${state.userLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF137333), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield, color: Color(0xFF137333), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Geocerca Activa',
                        style: TextStyle(color: Color(0xFF137333), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Simulated Interactive Map Canvas (M2)
          Expanded(
            child: Stack(
              children: [
                // Render Canvas representing Lima coordinates
                Container(
                  color: const Color(0xFFE8F0FE), // Google Maps background color
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _MapCanvasPainter(
                      clients: state.clientes,
                      userLat: state.userLat,
                      userLng: state.userLng,
                      selectedClient: activeClient,
                    ),
                  ),
                ),
                
                // Overlay touch areas for interactive markers
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    
                    return Stack(
                      children: state.clientes.map((client) {
                        // Math to project lat/lng onto canvas screen space
                        final pos = _projectCoordinates(
                          client.latitud,
                          client.longitud,
                          state.userLat,
                          state.userLng,
                          width,
                          height,
                        );

                        // If out of bounds, hide
                        if (pos.dx < 0 || pos.dx > width || pos.dy < 0 || pos.dy > height) {
                          return const SizedBox.shrink();
                        }

                        // Determine marker color
                        Color markerColor = const Color(0xFF087A4B); // Green
                        if (client.tipoGestion.toLowerCase() == 'mora') {
                          markerColor = const Color(0xFFB91C1C); // Red
                        } else if (client.tipoGestion.toLowerCase() == 'renovación' || client.tipoGestion.toLowerCase() == 'renovacion') {
                          markerColor = const Color(0xFFEAB308); // Yellow
                        }

                        final isSelected = activeClient?.id == client.id;

                        return Positioned(
                          left: pos.dx - (isSelected ? 20 : 15),
                          top: pos.dy - (isSelected ? 40 : 30),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedClient = client;
                              });
                            },
                            child: Tooltip(
                              message: client.nombre,
                              child: Icon(
                                Icons.location_on,
                                color: markerColor,
                                size: isSelected ? 40 : 30,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // Map Legend
                Positioned(
                  top: 10,
                  right: 10,
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendRow(color: Color(0xFFB91C1C), text: 'Prioridad Alta / Mora'),
                          SizedBox(height: 4),
                          _LegendRow(color: Color(0xFFEAB308), text: 'Prioridad Media / Renovación'),
                          SizedBox(height: 4),
                          _LegendRow(color: Color(0xFF087A4B), text: 'Prioridad Baja / Ampliación'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Selection Details and Launch Map Buttons
          if (activeClient != null)
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFEC0000).withOpacity(0.1),
                          child: const Icon(Icons.person, color: Color(0xFFEC0000)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeClient.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                activeClient.negocioNombre,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          onPressed: () {
                            notifier.updateBusinessCoords(activeClient.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coordenadas de negocio actualizadas.')),
                            );
                          },
                          tooltip: 'Actualizar GPS Negocio',
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ubicación del Negocio:',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          'Lat: ${activeClient.latitud.toStringAsFixed(4)}, Lng: ${activeClient.longitud.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openExternalMap(activeClient, 'google'),
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text('GOOGLE MAPS', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openExternalMap(activeClient, 'waze'),
                            icon: const Icon(Icons.directions_car, size: 18),
                            label: const Text('WAZE', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF33CCFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Projection math
  static Offset _projectCoordinates(
    double lat,
    double lng,
    double userLat,
    double userLng,
    double width,
    double height,
  ) {
    const latSpan = 0.2; // roughly 20km area
    const lngSpan = 0.2;

    final dx = ((lng - (userLng - lngSpan / 2)) / lngSpan) * width;
    final dy = (1 - ((lat - (userLat - latSpan / 2)) / latSpan)) * height;

    return Offset(dx, dy);
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Custom Painter to draw streets grid, geofences, and optimized route path lines (M2)
class _MapCanvasPainter extends CustomPainter {
  _MapCanvasPainter({
    required this.clients,
    required this.userLat,
    required this.userLng,
    required this.selectedClient,
  });

  final List<ClienteModel> clients;
  final double userLat;
  final double userLng;
  final ClienteModel? selectedClient;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw Simulated Grid Streets
    final gridPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0;

    for (int i = 0; i < 8; i++) {
      final y = (height / 8) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
      final x = (width / 8) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    // 2. Draw Geofence Zone (Shaded Circle Overlay - M2)
    final geofencePaint = Paint()
      ..color = Colors.blue.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    
    final userPos = _RutaScreenState._projectCoordinates(userLat, userLng, userLat, userLng, width, height);
    canvas.drawCircle(userPos, min(width, height) * 0.45, geofencePaint);

    final geofenceBorder = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(userPos, min(width, height) * 0.45, geofenceBorder);

    // 3. Draw Optimized Routing Path (Lines connecting nodes - M2)
    if (clients.isNotEmpty) {
      final pathPaint = Paint()
        ..color = const Color(0xFFEC0000).withOpacity(0.7)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final path = Path();
      
      // Start at User GPS
      path.moveTo(userPos.dx, userPos.dy);

      for (final client in clients) {
        final clientPos = _RutaScreenState._projectCoordinates(
          client.latitud,
          client.longitud,
          userLat,
          userLng,
          width,
          height,
        );
        path.lineTo(clientPos.dx, clientPos.dy);
      }

      canvas.drawPath(path, pathPaint);
    }

    // 4. Draw User Position Marker (Blue circle)
    final userMarkerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final userMarkerBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(userPos, 8.0, userMarkerPaint);
    canvas.drawCircle(userPos, 8.0, userMarkerBorder);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.clients != clients ||
        oldDelegate.userLat != userLat ||
        oldDelegate.userLng != userLng ||
        oldDelegate.selectedClient != selectedClient;
  }
}
