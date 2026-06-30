import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/database_helper.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../viewmodels/cartera_viewmodel.dart';

class ProspectosScreen extends ConsumerStatefulWidget {
  const ProspectosScreen({super.key});

  @override
  ConsumerState<ProspectosScreen> createState() => _ProspectosScreenState();
}

class _ProspectosScreenState extends ConsumerState<ProspectosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _docController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessController = TextEditingController();
  final _incomeController = TextEditingController();

  bool _isEvaluating = false;
  String? _preEvalResult; // Apto, Revisar, No procede
  String _preEvalMsg = '';

  List<Map<String, dynamic>> _savedProspects = [];

  // Campaigns list (M4)
  final List<Map<String, String>> _campaigns = [
    {
      'name': 'Campaña Fiestas Patrias - Renovación Exclusiva',
      'detail': 'Tasa especial de 11.5% TEA para clientes puntuales. Montos de hasta S/ 5,000.',
      'tag': 'Renovación',
    },
    {
      'name': 'Campaña Ampliación Primavera - Comercio',
      'detail': 'Dirigido a bodegas y puestos de mercado. Incremento de hasta 50% en monto inicial.',
      'tag': 'Ampliación',
    },
    {
      'name': 'Campaña Reactivación - Ex-clientes',
      'detail': 'Para clientes desertores sin mora en los últimos 2 años. Proceso 100% digital sin papeles.',
      'tag': 'Reactivación',
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProspects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _docController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _loadProspects() async {
    final list = await DatabaseHelper.instance.queryAll('prospectos');
    setState(() {
      _savedProspects = list;
    });
  }

  Future<void> _runPreEvaluation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEvaluating = true;
      _preEvalResult = null;
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate calculation

    final doc = _docController.text.trim();
    final income = double.tryParse(_incomeController.text) ?? 0.0;

    String result;
    String message;

    if (income < 900) {
      result = 'No procede';
      message = 'Ingresos mensuales declarados por debajo del mínimo vital requerido.';
    } else if (doc.endsWith('5') || doc.endsWith('0')) {
      result = 'Revisar';
      message = 'El cliente registra créditos activos en otros bancos. Requiere validación de analista de riesgos.';
    } else {
      result = 'Apto';
      message = 'Cliente cumple con filtros preliminares. Proceda a iniciar solicitud de crédito.';
    }

    // Capture location for offline prospect
    double lat = -12.12;
    double lng = -77.03;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 2),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    final prospectData = {
      'documento': doc,
      'nombre': _nameController.text.trim(),
      'telefono': _phoneController.text.trim(),
      'negocio_nombre': _businessController.text.trim(),
      'ingresos': income,
      'pre_evaluacion': result,
      'motivo_desercion': '',
      'latitud': lat,
      'longitud': lng,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };

    await DatabaseHelper.instance.insert('prospectos', prospectData);
    await SupabaseService.instance.upsertProspectoEnCarteraLocal(prospectData);
    await ref.read(carteraProvider.notifier).loadPortfolio();
    await _loadProspects();

    setState(() {
      _isEvaluating = false;
      _preEvalResult = result;
      _preEvalMsg = message;
    });

    SyncService.instance.checkConnectivityAndSync();
  }

  void _showDefectorDialog(BuildContext context, String doc) {
    String selectedReason = 'Tasa de interés muy alta';
    final customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Registrar Deserción', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Indique el motivo por el cual el cliente declinó la oferta:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Tasa de interés muy alta', child: Text('Tasa muy alta')),
                  DropdownMenuItem(value: 'Prefiere financiamiento informal', child: Text('Financiador informal / panderos')),
                  DropdownMenuItem(value: 'Monto aprobado insuficiente', child: Text('Poco monto aprobado')),
                  DropdownMenuItem(value: 'Ya no requiere capital de trabajo', child: Text('Ya no necesita capital')),
                  DropdownMenuItem(value: 'Otros', child: Text('Otros')),
                ],
                onChanged: (val) {
                  if (val != null) selectedReason = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customReasonController,
                decoration: InputDecoration(
                  hintText: 'Detalles del desistimiento (opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = selectedReason == 'Otros' 
                    ? customReasonController.text.trim() 
                    : '$selectedReason. ${customReasonController.text.trim()}';

                await DatabaseHelper.instance.update(
                  'prospectos', 
                  {
                    'motivo_desercion': reason,
                    'synced': 0,
                  }, 
                  'documento = ?', 
                  [doc]
                );

                Navigator.pop(context);
                _loadProspects();
                SyncService.instance.checkConnectivityAndSync();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registro de cliente desertor guardado.'),
                    backgroundColor: Color(0xFF087A4B),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('GUARDAR DESERCIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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
        title: const Text('Pre-evaluación y Prospección', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person_add), text: 'NUEVO PROSPECTO'),
            Tab(icon: Icon(Icons.campaign), text: 'CAMPAÑAS / DESERCIONES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Form & Local Registry
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: _formKey,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Registro de Prospecto en Campo',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _docController,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            decoration: InputDecoration(
                              labelText: 'Número de DNI',
                              prefixIcon: const Icon(Icons.badge),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || val.length != 8) ? 'DNI debe ser de 8 dígitos' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nombres y Apellidos del Prospecto',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingrese nombre completo' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 9,
                            decoration: InputDecoration(
                              labelText: 'Teléfono Móvil',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || val.length != 9) ? 'Celular debe ser de 9 dígitos' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _businessController,
                            decoration: InputDecoration(
                              labelText: 'Nombre / Razón Social del Negocio',
                              prefixIcon: const Icon(Icons.store),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingrese nombre del negocio' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _incomeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Ingresos Mensuales Promedio (S/)',
                              prefixIcon: const Icon(Icons.monetization_on_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) => (val == null || double.tryParse(val) == null) ? 'Ingrese monto de ingresos válido' : null,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _isEvaluating ? null : _runPreEvaluation,
                            icon: const Icon(Icons.rule),
                            label: const Text('CALCULAR PRE-EVALUACIÓN', style: TextStyle(fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC0000),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Result Panel (M4)
                if (_preEvalResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _preEvalResult == 'Apto'
                          ? const Color(0xFFE6F4EA)
                          : _preEvalResult == 'Revisar'
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _preEvalResult == 'Apto'
                            ? const Color(0xFF137333)
                            : _preEvalResult == 'Revisar'
                                ? const Color(0xFFD97706)
                                : const Color(0xFFB91C1C),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _preEvalResult == 'Apto'
                                  ? Icons.check_circle
                                  : _preEvalResult == 'Revisar'
                                      ? Icons.warning
                                      : Icons.cancel,
                              color: _preEvalResult == 'Apto'
                                  ? const Color(0xFF137333)
                                  : _preEvalResult == 'Revisar'
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'RESULTADO: ${_preEvalResult!.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _preEvalResult == 'Apto'
                                    ? const Color(0xFF137333)
                                    : _preEvalResult == 'Revisar'
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _preEvalMsg,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Text('Prospectos Registrados Hoy:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                ..._savedProspects.map((p) {
                  final isDesertor = (p['motivo_desercion'] ?? '').toString().isNotEmpty;
                  final preEval = p['pre_evaluacion'] ?? 'Apto';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(p['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p['negocio_nombre']} • Ingreso: S/ ${p['ingresos']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: preEval == 'Apto' 
                                  ? Colors.green.shade100 
                                  : preEval == 'Revisar' 
                                      ? Colors.orange.shade100 
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              preEval, 
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: preEval == 'Apto' 
                                    ? Colors.green.shade800 
                                    : preEval == 'Revisar' 
                                        ? Colors.orange.shade800 
                                        : Colors.red.shade800,
                              ),
                            ),
                          ),
                          if (!isDesertor) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.cancel_presentation, color: Colors.grey),
                              tooltip: 'Marcar como Desertor',
                              onPressed: () => _showDefectorDialog(context, p['documento']),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            const Text(
                              'DESERTOR',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Tab 2: Campaigns & Desertions
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Campañas Activas de Campo',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ..._campaigns.map((camp) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                camp['name']!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEC0000).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                camp['tag']!.toUpperCase(),
                                style: const TextStyle(color: Color(0xFFEC0000), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          camp['detail']!,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
