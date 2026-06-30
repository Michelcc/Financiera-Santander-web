import 'dart:math';
import 'package:flutter/material.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key, required this.applicationId, required this.onCompleted});

  final String applicationId;
  final Function(Map<String, String> photoPaths, bool nitidezOk) onCompleted;

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final Map<String, String> _photoPaths = {}; // docType -> mock path/indicator
  final Map<String, double> _photoNitidez = {}; // docType -> laplacian variance score
  final Map<String, bool> _photoUploading = {};

  final List<String> _requiredDocs = [
    'DNI Anverso',
    'DNI Reverso',
    'Fachada del Negocio',
    'Cliente con Asesor (Selfie)',
  ];

  Future<void> _capturePhoto(String docType) async {
    setState(() {
      _photoUploading[docType] = true;
    });

    // Simulate camera delay
    await Future.delayed(const Duration(seconds: 1));

    // Simulate Laplacian variance calculation (random between 5.0 and 45.0)
    // 5.0 to 9.9 will represent blurry (for demonstration), >= 10.0 is sharp
    final random = Random();
    final isBlurry = random.nextDouble() < 0.15; // 15% chance of blurry for demo testing
    final variance = isBlurry ? (random.nextDouble() * 4.9 + 5.0) : (random.nextDouble() * 30.0 + 12.0);

    setState(() {
      _photoPaths[docType] = 'cache_${widget.applicationId}_${docType.replaceAll(' ', '_')}.jpg';
      _photoNitidez[docType] = variance;
      _photoUploading[docType] = false;
    });

    if (isBlurry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto de $docType muy borrosa (Var: ${variance.toStringAsFixed(1)}). Por favor, repita la toma.'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  bool get _allCaptured {
    return _requiredDocs.every((doc) => _photoPaths.containsKey(doc));
  }

  bool get _allNitido {
    return _photoNitidez.values.every((v) => v >= 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
        title: const Text('Captura de Documentos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions header
            Card(
              color: Colors.grey.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Icon(Icons.camera_enhance, color: Color(0xFFEC0000)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Validación de Nitidez en Tiempo Real',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Las fotos se validan automáticamente con filtro Laplaciano (<800KB). Si la varianza es menor a 10.0, deberá repetir la toma.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Document capture cards list
            Expanded(
              child: ListView.builder(
                itemCount: _requiredDocs.length,
                itemBuilder: (context, index) {
                  final doc = _requiredDocs[index];
                  final isCaptured = _photoPaths.containsKey(doc);
                  final isUploading = _photoUploading[doc] == true;
                  final variance = _photoNitidez[doc] ?? 0.0;
                  final isSharp = variance >= 10.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isCaptured
                                  ? (isSharp ? Colors.green.shade50 : Colors.red.shade50)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCaptured
                                    ? (isSharp ? Colors.green.shade200 : Colors.red.shade200)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: isUploading
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Icon(
                                    isCaptured
                                        ? (isSharp ? Icons.check : Icons.warning_amber)
                                        : Icons.photo_camera,
                                    color: isCaptured
                                        ? (isSharp ? const Color(0xFF137333) : const Color(0xFFB91C1C))
                                        : Colors.grey,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (isCaptured) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Laplacian Var: ${variance.toStringAsFixed(1)} ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSharp ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSharp ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isSharp ? 'NÍTIDO' : 'BORROSO',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: isSharp ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Compreso: ~640KB • JPG',
                                    style: TextStyle(color: Colors.grey, fontSize: 10),
                                  ),
                                ] else
                                  const Text(
                                    'Pendiente de captura',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isUploading ? null : () => _capturePhoto(doc),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCaptured ? Colors.grey.shade200 : const Color(0xFFEC0000),
                              foregroundColor: isCaptured ? Colors.black87 : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              isCaptured ? 'REPETIR' : 'CAPTURAR',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            ElevatedButton(
              onPressed: _allCaptured
                  ? () {
                      widget.onCompleted(_photoPaths, _allNitido);
                      Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _allCaptured
                    ? (_allNitido ? 'PROSEGUIR CON FOTOS VALIDADAS' : 'CONTINUAR (REQUIERE AJUSTAR FOTOS)')
                    : 'FAVOR CAPTURAR TODAS LAS FOTOS',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
