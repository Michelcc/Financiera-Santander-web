import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/cliente_model.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';

class RecuperacionScreen extends StatefulWidget {
  const RecuperacionScreen({super.key});

  @override
  State<RecuperacionScreen> createState() => _RecuperacionScreenState();
}

class _RecuperacionScreenState extends State<RecuperacionScreen> {
  List<ClienteModel> _overdueClients = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _collectionLogs = [];

  @override
  void initState() {
    super.initState();
    _loadOverduePortfolio();
  }

  Future<void> _loadOverduePortfolio() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final list = await db.queryAll('clientes');
    
    // Filter clients with mora
    final List<ClienteModel> allClients = list.map(ClienteModel.fromMap).toList();
    final overdue = allClients.where((c) => c.moraDias > 0).toList();

    // Sort by mora severity (days desc)
    overdue.sort((a, b) => b.moraDias.compareTo(a.moraDias));

    final logs = await db.queryAll('acciones_cobranza');

    setState(() {
      _overdueClients = overdue;
      _collectionLogs = logs;
      _isLoading = false;
    });
  }

  Color _getMoraColor(int days) {
    if (days > 60) return const Color(0xFFDC2626); // Red
    if (days > 30) return const Color(0xFFF97316); // Orange
    return const Color(0xFFEAB308); // Yellow
  }

  void _showCollectionDialog(BuildContext context, ClienteModel client) {
    String selectedType = 'Visita Domiciliaria';
    final observationController = TextEditingController();
    DateTime? promiseDate;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.payment, color: Color(0xFFEC0000)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gestión de Cobro: ${client.nombre.split(' ').first}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Acción de Cobranza Ejecutada:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Visita Domiciliaria', child: Text('Visita Domiciliaria')),
                        DropdownMenuItem(value: 'Llamada Telefónica', child: Text('Llamada Telefónica')),
                        DropdownMenuItem(value: 'Notificación Escrita', child: Text('Notificación Escrita')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Detalles / Observaciones:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: observationController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ej. Hablé con cliente, indica que pagará el lunes.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('¿Registrar Compromiso de Pago? (Opcional):'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 3)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date != null) {
                          setDialogState(() => promiseDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(promiseDate == null 
                          ? 'SELECCIONAR FECHA COMPROMISO' 
                          : 'COMPROMISO: ${promiseDate!.day}/${promiseDate!.month}/${promiseDate!.year}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                      ),
                    ),
                    if (promiseDate != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Monto del Compromiso (S/)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final logId = 'col_${client.id}_${DateTime.now().millisecondsSinceEpoch}';
                    
                    // Capture location
                    double lat = client.latitud;
                    double lng = client.longitud;
                    try {
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.medium,
                        timeLimit: const Duration(seconds: 2),
                      );
                      lat = pos.latitude;
                      lng = pos.longitude;
                    } catch (_) {}

                    final logData = {
                      'id': logId,
                      'cliente_id': client.id,
                      'tipo': selectedType,
                      'observacion': observationController.text.trim(),
                      'compromiso_fecha': promiseDate?.toIso8601String() ?? '',
                      'compromiso_monto': double.tryParse(amountController.text) ?? 0.0,
                      'latitud': lat,
                      'longitud': lng,
                      'created_at': DateTime.now().toIso8601String(),
                      'synced': 0,
                    };

                    await DatabaseHelper.instance.insert('acciones_cobranza', logData);
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadOverduePortfolio();
                      SyncService.instance.checkConnectivityAndSync();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acción de cobranza registrada localmente.'),
                          backgroundColor: Color(0xFF087A4B),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC0000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('GUARDAR ACCIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text('Recuperación de Cartera', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC0000)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFFEC0000).withOpacity(0.06),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.report_problem, color: Color(0xFFEC0000)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tiene ${_overdueClients.length} clientes en mora asignados hoy. Priorice las visitas de color rojo.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _overdueClients.isEmpty
                      ? const Center(child: Text('Felicidades! No tiene clientes vencidos asignados.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _overdueClients.length,
                          itemBuilder: (context, index) {
                            final client = _overdueClients[index];
                            final color = _getMoraColor(client.moraDias);
                            
                            // Find any logged actions for this client today
                            final clientLogs = _collectionLogs.where((l) => l['cliente_id'] == client.id).toList();

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            client.nombre,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Urgency traffic-light badge (M10)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: color.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            '${client.moraDias} días',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      client.negocioNombre,
                                      style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Monto en Mora: S/ ${client.deudaTotal.toStringAsFixed(0)} • DNI: ${client.documento}',
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                    ),
                                    
                                    if (clientLogs.isNotEmpty) ...[
                                      const Divider(height: 20),
                                      const Text(
                                        'Gestiones registradas hoy:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      ...clientLogs.map((log) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Text(
                                          '• ${log['tipo']}: ${log['observacion']}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      )),
                                    ],

                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          clientLogs.isNotEmpty ? 'GESTIÓN COMPLETA' : 'PENDIENTE ACCIÓN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: clientLogs.isNotEmpty ? const Color(0xFF137333) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _showCollectionDialog(context, client),
                                          icon: const Icon(Icons.add_task, size: 16),
                                          label: const Text('Registrar Cobro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEC0000),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
