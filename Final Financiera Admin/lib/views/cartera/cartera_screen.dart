import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/tipo_gestion_helper.dart';
import '../../models/cliente_model.dart';
import '../../viewmodels/cartera_viewmodel.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';
import '../cliente/ficha_cliente_screen.dart';

class CarteraScreen extends ConsumerStatefulWidget {
  const CarteraScreen({super.key});

  @override
  ConsumerState<CarteraScreen> createState() => _CarteraScreenState();
}

class _CarteraScreenState extends ConsumerState<CarteraScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(carteraProvider);
    final notifier = ref.read(carteraProvider.notifier);

    // Apply search and filter
    final filteredClients = state.clientes.where((c) {
      final matchesSearch = c.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.negocioNombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.documento.contains(_searchQuery);
      
      final matchesFilter =
          TipoGestionHelper.matchesFilter(c.tipoGestion, _selectedFilter);

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: SantanderAppBar(
        title: 'Mi Cartera Diaria',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.syncFromServer(),
            tooltip: 'Sincronizar Cartera',
          ),
        ],
      ),
      body: state.isLoading
          ? const SantanderLoading(message: 'Sincronizando cartera...')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.clientes.isEmpty && state.error == null && !state.isLoading)
                  MaterialBanner(
                    backgroundColor: Colors.blue.shade50,
                    content: const Text(
                      'Cartera vacía. Toque ↻ arriba para sincronizar. '
                      'Si persiste, ejecute supabase_admin_cartera_final.sql en Supabase.',
                      style: TextStyle(fontSize: 12),
                    ),
                    leading: Icon(Icons.info_outline, color: Colors.blue.shade900),
                    actions: [
                      TextButton(
                        onPressed: () => notifier.syncFromServer(),
                        child: const Text('Sincronizar'),
                      ),
                    ],
                  ),
                if (state.error != null && state.clientes.isEmpty)
                  MaterialBanner(
                    backgroundColor: Colors.red.shade100,
                    content: Text(
                      state.error!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    leading: Icon(Icons.error_outline, color: Colors.red.shade900),
                    actions: [
                      TextButton(
                        onPressed: () => notifier.syncFromServer(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                if (state.isOffline || state.fromCache)
                  MaterialBanner(
                    backgroundColor: Colors.amber.shade100,
                    content: Text(
                      state.isOffline
                          ? 'Modo offline — mostrando caché local'
                          : 'Datos desde caché — sin conexión al servidor',
                      style: const TextStyle(fontSize: 13),
                    ),
                    leading: Icon(
                      state.isOffline ? Icons.cloud_off : Icons.cloud_queue,
                      color: Colors.amber.shade900,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => notifier.syncFromServer(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                // Portfolio progress bar and optimize route actions
                Container(
                  color: const Color(0xFFEC0000),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progreso de Visitas: ${(state.progressPercentage * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${state.visitasHoy.length} / ${state.clientes.length} completados',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: state.progressPercentage,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          notifier.optimizeRoute();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ruta optimizada por vecino más cercano.'),
                              backgroundColor: Color(0xFF087A4B),
                            ),
                          );
                        },
                        icon: const Icon(Icons.alt_route),
                        label: Text(
                          state.isRouteOptimized ? 'RUTA OPTIMIZADA' : 'OPTIMIZAR SECUENCIA DE RUTA',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.25),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Filters and search
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente por nombre o DNI...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

                // Management Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: TipoGestionHelper.filterChips.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFEC0000),
                          backgroundColor: Colors.grey.shade200,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Client List (Drag and Drop / Reorderable - M1)
                Expanded(
                  child: filteredClients.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_list_off,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  state.clientes.isEmpty
                                      ? 'No hay clientes en cartera.\nPulse ↻ para sincronizar.\n\nSi sigue vacío, ejecute supabase_reparar_rapido.sql en Supabase.'
                                      : 'Hay ${state.clientes.length} clientes pero ninguno coincide con el filtro "$_selectedFilter".',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                if (state.clientes.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () =>
                                        setState(() => _selectedFilter = 'Todos'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEC0000),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('VER TODOS'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          onReorder: (oldIndex, newIndex) =>
                              notifier.reorderClientsById(
                            filteredClients,
                            oldIndex,
                            newIndex,
                          ),
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            final hasVisited = state.visitasHoy.containsKey(client.id);
                            final visitResult = state.visitasHoy[client.id];

                            return _ClientCard(
                              key: ValueKey(client.id),
                              client: client,
                              hasVisited: hasVisited,
                              visitResult: visitResult,
                              index: index,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FichaClienteScreen(client: client),
                                  ),
                                );
                              },
                              onVisit: () => _showVisitDialog(context, client.id),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showVisitDialog(BuildContext context, String clientId) {
    final resultController = TextEditingController();
    String selectedResult = 'Interesado - Agendar Solicitud';
    final observationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_road, color: Color(0xFFEC0000)),
              SizedBox(width: 8),
              Text(
                'Registrar Visita',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Seleccione el resultado de la gestión en campo:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedResult,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Interesado - Agendar Solicitud',
                      child: Text('Interesado - Agendar Solicitud'),
                    ),
                    DropdownMenuItem(
                      value: 'No contactado / Ausente',
                      child: Text('No contactado / Ausente'),
                    ),
                    DropdownMenuItem(
                      value: 'Rechazó Oferta / No le interesa',
                      child: Text('Rechazó Oferta'),
                    ),
                    DropdownMenuItem(
                      value: 'Mudar de Local / Cerrado',
                      child: Text('Local Cerrado o Mudado'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedResult = val;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Observaciones de campo:'),
                const SizedBox(height: 8),
                TextField(
                  controller: observationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Detalles de la visita, condición del local, etc.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(carteraProvider.notifier).logVisit(
                      clientId: clientId,
                      result: selectedResult,
                      observation: observationController.text.trim(),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Visita registrada localmente para sincronización.'),
                    backgroundColor: Color(0xFF087A4B),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('GUARDAR GESTIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required super.key,
    required this.client,
    required this.hasVisited,
    required this.visitResult,
    required this.index,
    required this.onTap,
    required this.onVisit,
  });

  final ClienteModel client;
  final bool hasVisited;
  final String? visitResult;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onVisit;

  Color _getManagementColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'mora':
        return const Color(0xFFB91C1C); // Crimson Red
      case 'ampliación':
      case 'ampliacion':
        return const Color(0xFFEA580C); // Dark Orange
      case 'renovación':
      case 'renovacion':
      default:
        return const Color(0xFF087A4B); // Santander Green/Emerald
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getManagementColor(client.tipoGestion);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color stripe indicating type of management (M1)
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Client Name and Sequence Number
                        Expanded(
                          child: Text(
                            '${index + 1}. ${client.nombre}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1C1C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Management badge type
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            client.tipoGestion.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      client.negocioNombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-aprobado: S/ ${client.montoPreaprobado.toStringAsFixed(0)} • DNI: ${client.documento}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Buttons and visit status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Ficha'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                        
                        hasVisited
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4EA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF137333), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      visitResult?.split(' ').first ?? 'Gestionado',
                                      style: const TextStyle(
                                        color: Color(0xFF137333),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: onVisit,
                                icon: const Icon(Icons.edit_road, size: 16),
                                label: const Text('Visitar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEC0000),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Reordering drag-handle handle
            const ReorderableDragStartListener(
              index: 0, // Injected by builder automatically
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.drag_indicator, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
