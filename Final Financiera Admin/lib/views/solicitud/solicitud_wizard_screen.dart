import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/cliente_model.dart';
import '../../services/calculadora_credito.dart';
import '../../services/database_helper.dart';
import '../../services/scoring_service.dart';
import '../../services/sync_service.dart';
import 'documentos_screen.dart';

class SolicitudWizardScreen extends StatefulWidget {
  const SolicitudWizardScreen({super.key, required this.client});

  final ClienteModel client;

  @override
  State<SolicitudWizardScreen> createState() => _SolicitudWizardScreenState();
}

class _SolicitudWizardScreenState extends State<SolicitudWizardScreen> {
  int _currentStep = 0;
  final _wizardFormKey = GlobalKey<FormState>();

  // --- STEP 1: Personal Data ---
  final _ageController = TextEditingController(text: '35');
  String _civilStatus = 'Soltero';
  final _spouseNameController = TextEditingController();
  final _spouseDniController = TextEditingController();

  // --- STEP 2: Business Data ---
  final _salesController = TextEditingController(text: '120');
  final _expensesController = TextEditingController(text: '800');
  String _creditDestination = 'Capital de Trabajo';

  // --- STEP 3: Field Evaluation (F1 - F5) & Simulator ---
  bool _f1NegocioVerificado = true;
  double _f1Points = 45.0; // Antiguedad + Tenencia
  double _f2Points = 40.0; // Ventas + Gastos
  double _f3Points = 20.0; // Deuda informal
  double _f4Points = 25.0; // Stock + activos
  bool _f5VetoCaracter = false;

  bool _scoringEvaluated = false;
  ScoringResult? _scoringResult;

  double _requestedAmount = 1000.0;
  int _requestedTerm = 6;
  String _paymentFrequency = 'Mensual';

  // --- STEP 4: Confirm & Digital Signature ---
  final List<Offset?> _signaturePoints = [];
  bool _photosCaptured = false;
  Map<String, String> _capturedPhotos = {};
  bool _photosNitido = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _ageController.dispose();
    _spouseNameController.dispose();
    _spouseDniController.dispose();
    _salesController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  void _runFieldScoring() {
    // Average Monthly Income Estimate = Daily sales * 26 working days - Fixed costs
    final dailySales = double.tryParse(_salesController.text) ?? 100.0;
    final fixedCosts = double.tryParse(_expensesController.text) ?? 800.0;
    final estimatedIncome = max(300.0, (dailySales * 26) - fixedCosts);

    final result = ScoringService.evaluar(
      scoreTransaccional: widget.client.scoreTransaccional,
      ingresoPromedio: estimatedIncome,
      negocioVerificado: _f1NegocioVerificado,
      f1AntiguedadPuntos: (_f1Points * 0.4).round(), // split points for f1
      f1LocalTenenciaPuntos: (_f1Points * 0.6).round(),
      f2ConsistenciaVentasPuntos: (_f2Points * 0.5).round(),
      f2ControlGastosPuntos: (_f2Points * 0.5).round(),
      f3DeudaInformalPuntos: _f3Points.round(),
      f4StockActivosPuntos: _f4Points.round(),
      f5VetoCaracter: _f5VetoCaracter,
    );

    setState(() {
      _scoringResult = result;
      _scoringEvaluated = true;
      if (result.aprobado) {
        _requestedAmount = result.montoMaximo;
        _requestedTerm = result.plazoMaximoMeses;
      } else {
        _requestedAmount = 0;
        _requestedTerm = 0;
      }
    });
  }

  Future<void> _saveDraft({required bool submit}) async {
    if (submit && !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe aceptar la declaración jurada y firmar la solicitud.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    if (submit && _signaturePoints.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor solicite la firma del cliente antes de enviar.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    final applicationId = 'sol_${widget.client.id}_${DateTime.now().millisecondsSinceEpoch}';

    // Serialize form values to JSON strings for simplicity
    final personalData = {
      'dni': widget.client.documento,
      'nombre': widget.client.nombre,
      'edad': _ageController.text,
      'estado_civil': _civilStatus,
      'conyuge_nombre': _spouseNameController.text,
      'conyuge_dni': _spouseDniController.text,
    };

    final businessData = {
      'negocio_nombre': widget.client.negocioNombre,
      'negocio_giro': widget.client.negocioTipo,
      'direccion': widget.client.direccion,
      'ventas_diarias': _salesController.text,
      'gastos_mensuales': _expensesController.text,
      'destino_credito': _creditDestination,
    };

    final conditions = {
      'monto_solicitado': _requestedAmount,
      'plazo_cuotas': _requestedTerm,
      'frecuencia': _paymentFrequency,
      'score_campo': _scoringResult?.scoreCampo ?? 0,
      'score_final': _scoringResult?.scoreFinal ?? 0,
    };

    // Calculate simulation cuota french formula
    final simulation = CalculadoraCredito.simular(
      monto: _requestedAmount,
      plazoCuotas: _requestedTerm,
      frecuencia: _paymentFrequency,
      tea: _scoringResult?.tasaInteres ?? 0.45,
    );

    final row = {
      'id': applicationId,
      'cliente_id': widget.client.id,
      'datos_personales': personalData.toString(),
      'datos_negocio': businessData.toString(),
      'condiciones': conditions.toString(),
      'firma_path': 'local_signature_$applicationId.png',
      'nitidez_ok': _photosNitido ? 1 : 0,
      'fotos_paths': _capturedPhotos.toString(),
      'score_campo': _scoringResult?.scoreCampo ?? 0,
      'score_final': _scoringResult?.scoreFinal ?? 0,
      'segmento': _scoringResult?.segmento ?? 'NO APLICA',
      'monto_aprobado': _requestedAmount,
      'plazo_aprobado': _requestedTerm,
      'cuota_mensual': simulation.cuotaMonto,
      'estado': submit ? 'Pendiente' : 'Borrador',
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };

    await DatabaseHelper.instance.insert('solicitudes_borradores', row);
    
    // Trigger background sync
    SyncService.instance.checkConnectivityAndSync();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submit 
              ? 'Solicitud transmitida correctamente al comité.' 
              : 'Solicitud guardada en borradores locales.'),
          backgroundColor: const Color(0xFF087A4B),
        ),
      );
      Navigator.pop(context); // Go back to client sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simulator calculations in real-time if scoring is approved
    ResultadoSimulacion? simulation;
    if (_scoringEvaluated && _scoringResult != null && _scoringResult!.aprobado && _requestedAmount > 0) {
      simulation = CalculadoraCredito.simular(
        monto: _requestedAmount,
        plazoCuotas: _requestedTerm,
        frecuencia: _paymentFrequency,
        tea: _scoringResult!.tasaInteres,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: Text(
          'Solicitud: Paso ${_currentStep + 1} de 4',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _wizardFormKey,
        child: Column(
          children: [
            // Wizard Steps indicator bar
            Container(
              color: const Color(0xFFEC0000).withOpacity(0.05),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StepIndicator(index: 0, activeIndex: _currentStep, label: 'Personales'),
                  _StepIndicator(index: 1, activeIndex: _currentStep, label: 'Negocio'),
                  _StepIndicator(index: 2, activeIndex: _currentStep, label: 'Score/Simula'),
                  _StepIndicator(index: 3, activeIndex: _currentStep, label: 'Firma/Docs'),
                ],
              ),
            ),
            
            // Step content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: _buildStepContent(simulation),
              ),
            ),

            // Next / Prev buttons footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('ATRÁS'),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  Row(
                    children: [
                      if (_currentStep < 3)
                        ElevatedButton(
                          onPressed: () {
                            if (_currentStep == 2 && (!_scoringEvaluated || _scoringResult == null || !_scoringResult!.aprobado)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Debe calcular y calificar la evaluación de campo (scoring) primero.'),
                                  backgroundColor: Color(0xFFB91C1C),
                                ),
                              );
                              return;
                            }
                            if (_wizardFormKey.currentState!.validate()) {
                              setState(() => _currentStep++);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC0000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('CONTINUAR'),
                        )
                      else ...[
                        OutlinedButton(
                          onPressed: () => _saveDraft(submit: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEC0000),
                            side: const BorderSide(color: Color(0xFFEC0000)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('GUARDAR BORRADOR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _saveDraft(submit: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC0000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('TRANSMITIR'),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(ResultadoSimulacion? simulation) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paso 1: Datos Personales del Solicitante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.client.nombre,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Nombres Completos', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.client.documento,
              enabled: false,
              decoration: const InputDecoration(labelText: 'DNI', prefixIcon: Icon(Icons.badge)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Edad del Solicitante', prefixIcon: Icon(Icons.cake)),
              validator: (val) {
                final num = int.tryParse(val ?? '');
                if (num == null || num < 18 || num > 85) return 'Edad inválida para crédito (18 - 85 años)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _civilStatus,
              decoration: const InputDecoration(labelText: 'Estado Civil', prefixIcon: Icon(Icons.people)),
              items: const [
                DropdownMenuItem(value: 'Soltero', child: Text('Soltero')),
                DropdownMenuItem(value: 'Casado', child: Text('Casado')),
                DropdownMenuItem(value: 'Divorciado', child: Text('Divorciado')),
                DropdownMenuItem(value: 'Viudo', child: Text('Viudo')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _civilStatus = val);
              },
            ),
            if (_civilStatus == 'Casado') ...[
              const SizedBox(height: 16),
              const Text('Datos del Cónyuge / Aval Garante:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _spouseNameController,
                decoration: const InputDecoration(labelText: 'Nombre Cónyuge', prefixIcon: Icon(Icons.person_add_alt)),
                validator: (val) => (_civilStatus == 'Casado' && (val == null || val.trim().isEmpty)) ? 'Ingrese nombre de cónyuge' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _spouseDniController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(labelText: 'DNI Cónyuge', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (val) => (_civilStatus == 'Casado' && (val == null || val.length != 8)) ? 'DNI cónyuge inválido' : null,
              ),
            ],
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paso 2: Negocio y Destino del Crédito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.client.negocioNombre,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Nombre Comercial', prefixIcon: Icon(Icons.store)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.client.direccion,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Dirección Comercial', prefixIcon: Icon(Icons.location_on)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _salesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Venta Diaria Promedio (S/)', prefixIcon: Icon(Icons.monetization_on)),
              validator: (val) => (val == null || double.tryParse(val) == null) ? 'Ingrese monto de venta' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expensesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gastos Fijos Mensuales (S/)', prefixIcon: Icon(Icons.remove_circle_outline)),
              validator: (val) => (val == null || double.tryParse(val) == null) ? 'Ingrese gastos fijos' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _creditDestination,
              decoration: const InputDecoration(labelText: 'Destino de Crédito', prefixIcon: Icon(Icons.shopping_bag)),
              items: const [
                DropdownMenuItem(value: 'Capital de Trabajo', child: Text('Capital de Trabajo / Mercadería')),
                DropdownMenuItem(value: 'Activo Fijo', child: Text('Activo Fijo / Maquinarias')),
                DropdownMenuItem(value: 'Ampliación Local', child: Text('Ampliación de Local Comercial')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _creditDestination = val);
              },
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paso 3: Evaluación de Campo (Scoring) y Simulador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            // F1: Verificación fisica
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('F1: Verificación Física & Tenencia (Antigüedad)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Row(
                      children: [
                        Checkbox(
                          value: _f1NegocioVerificado, 
                          activeColor: const Color(0xFFEC0000),
                          onChanged: (val) => setState(() => _f1NegocioVerificado = val ?? true),
                        ),
                        const Text('Negocio Verificado Físicamente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('Calificación Antigüedad y Tenencia: ${_f1Points.round()} pts (max 60)', style: const TextStyle(fontSize: 11)),
                    Slider(
                      value: _f1Points,
                      min: 0,
                      max: 60,
                      activeColor: const Color(0xFFEC0000),
                      onChanged: (val) => setState(() => _f1Points = val),
                    ),
                  ],
                ),
              ),
            ),
            
            // F2: Ventas y gastos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('F2: Ventas & Gastos Consistencia: ${_f2Points.round()} pts (max 60)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Slider(
                      value: _f2Points,
                      min: 0,
                      max: 60,
                      activeColor: const Color(0xFFEC0000),
                      onChanged: (val) => setState(() => _f2Points = val),
                    ),
                  ],
                ),
              ),
            ),
            
            // F3: Deuda informal
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('F3: Deuda Informal / Panderos: ${_f3Points.round()} pts (-50 a +40)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Slider(
                      value: _f3Points,
                      min: -50,
                      max: 40,
                      activeColor: const Color(0xFFEC0000),
                      onChanged: (val) => setState(() => _f3Points = val),
                    ),
                  ],
                ),
              ),
            ),
            
            // F4: Activos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('F4: Stock Visible & Activos: ${_f4Points.round()} pts (max 40)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Slider(
                      value: _f4Points,
                      min: 0,
                      max: 40,
                      activeColor: const Color(0xFFEC0000),
                      onChanged: (val) => setState(() => _f4Points = val),
                    ),
                  ],
                ),
              ),
            ),

            // F5: Veto
            Card(
              child: CheckboxListTile(
                title: const Text('F5: Veto por Carácter del Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB91C1C))),
                subtitle: const Text('Activar si se detecta perfil no cooperativo o deudor informal peligroso.', style: TextStyle(fontSize: 10)),
                value: _f5VetoCaracter,
                activeColor: const Color(0xFFB91C1C),
                onChanged: (val) => setState(() => _f5VetoCaracter = val ?? false),
              ),
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _runFieldScoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('EVALUAR CRÉDITO Y TOPE DE SEGMENTO'),
            ),
            
            if (_scoringEvaluated && _scoringResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _scoringResult!.aprobado ? const Color(0xFFE6F4EA) : const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _scoringResult!.aprobado ? const Color(0xFF137333) : const Color(0xFFB91C1C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scoringResult!.aprobado ? 'CRÉDITO APTO' : 'CRÉDITO RECHAZADO',
                      style: TextStyle(fontWeight: FontWeight.w900, color: _scoringResult!.aprobado ? const Color(0xFF137333) : const Color(0xFFB91C1C)),
                    ),
                    if (!_scoringResult!.aprobado) ...[
                      const SizedBox(height: 4),
                      Text('Motivo: ${_scoringResult!.motivoRechazo}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('Segmento: ${_scoringResult!.segmento} (Score final: ${_scoringResult!.scoreFinal})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Límite Máximo Aprobado: S/ ${_scoringResult!.montoMaximo.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Plazo Máximo: ${_scoringResult!.plazoMaximoMeses} meses', style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              
              if (_scoringResult!.aprobado) ...[
                const SizedBox(height: 20),
                const Text('Ajuste de Condiciones de Crédito:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Text('Monto solicitado: S/ ${_requestedAmount.round()}'),
                Slider(
                  value: _requestedAmount,
                  min: 200,
                  max: _scoringResult!.montoMaximo,
                  divisions: ((_scoringResult!.montoMaximo - 200) / 100).round(),
                  activeColor: const Color(0xFFEC0000),
                  onChanged: (val) => setState(() => _requestedAmount = val),
                ),
                Text('Plazo cuotas: $_requestedTerm'),
                Slider(
                  value: _requestedTerm.toDouble(),
                  min: 1,
                  max: _scoringResult!.plazoMaximoMeses.toDouble(),
                  divisions: _scoringResult!.plazoMaximoMeses - 1,
                  activeColor: const Color(0xFFEC0000),
                  onChanged: (val) => setState(() => _requestedTerm = val.round()),
                ),
                DropdownButtonFormField<String>(
                  value: _paymentFrequency,
                  decoration: const InputDecoration(labelText: 'Frecuencia de Pago'),
                  items: const [
                    DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
                    DropdownMenuItem(value: 'Quincenal', child: Text('Quincenal')),
                    DropdownMenuItem(value: 'Mensual', child: Text('Mensual')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentFrequency = val);
                  },
                ),
                if (simulation != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFFF7F7F7),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cuota (${_paymentFrequency}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('S/ ${simulation.cuotaMonto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEC0000))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total a pagar:'),
                              Text('S/ ${simulation.totalPagar.toStringAsFixed(2)}'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TEA referencial:'),
                              Text('${(_scoringResult!.tasaInteres * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paso 4: Captura de Documentos y Firma Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),

            // Photos button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentosScreen(
                      applicationId: widget.client.id,
                      onCompleted: (paths, nitido) {
                        setState(() {
                          _capturedPhotos = paths;
                          _photosCaptured = true;
                          _photosNitido = nitido;
                        });
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: Text(_photosCaptured 
                  ? 'DOCUMENTOS CAPTURADOS (${_capturedPhotos.length}/4)' 
                  : 'CAPTURAR FOTOS EXPEDIENTE (DNI, LOCAL, SELFIE)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _photosCaptured ? const Color(0xFF087A4B) : const Color(0xFFEC0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_photosCaptured && !_photosNitido) ...[
              const SizedBox(height: 6),
              const Text(
                'Nota: Algunas fotos capturadas presentan nitidez subóptima (<10.0 var Laplaciano).',
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),

            // Drawing Signature Board (M5)
            const Text('Firma Digital del Cliente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final localPos = box.globalToLocal(details.globalPosition);
                        setState(() {
                          _signaturePoints.add(Offset(localPos.dx, localPos.dy - 100));
                        });
                      }
                    },
                    onPanEnd: (_) => _signaturePoints.add(null),
                    child: CustomPaint(
                      painter: _WizardSignaturePainter(points: _signaturePoints),
                      size: Size.infinite,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEC0000)),
                      onPressed: () => setState(() => _signaturePoints.clear()),
                    ),
                  ),
                  if (_signaturePoints.isEmpty)
                    const Center(
                      child: Text('Dibuje firma del cliente aquí', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Declaration Jurada check
            CheckboxListTile(
              value: _termsAccepted,
              activeColor: const Color(0xFFEC0000),
              title: const Text(
                'Confirmo que todos los datos declarados y documentos fotográficos corresponden fielmente a la realidad verificada en campo.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onChanged: (val) => setState(() => _termsAccepted = val ?? false),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.index, required this.activeIndex, required this.label});
  final int index;
  final int activeIndex;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeIndex;
    final isDone = index < activeIndex;

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive
              ? const Color(0xFFEC0000)
              : isDone
                  ? const Color(0xFF087A4B)
                  : Colors.grey.shade300,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? const Color(0xFFEC0000)
                : isDone
                    ? const Color(0xFF087A4B)
                    : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _WizardSignaturePainter extends CustomPainter {
  _WizardSignaturePainter({required this.points});
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WizardSignaturePainter oldDelegate) => true;
}
