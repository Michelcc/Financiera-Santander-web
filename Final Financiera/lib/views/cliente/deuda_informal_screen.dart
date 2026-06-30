import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../services/cliente_supabase_service.dart';

class DeudaInformalScreen extends StatefulWidget {
  const DeudaInformalScreen({super.key});

  @override
  State<DeudaInformalScreen> createState() => _DeudaInformalScreenState();
}

class _DeudaInformalScreenState extends State<DeudaInformalScreen> {
  bool _tieneDeuda = false;
  final _montoController = TextEditingController();
  final _entidadController = TextEditingController();
  List<Map<String, dynamic>> _historial = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistorial();
  }

  Future<void> _loadHistorial() async {
    final data = await ClienteSupabaseService.instance.getDeclaraciones();
    if (mounted) setState(() => _historial = data);
  }

  Future<void> _guardar() async {
    setState(() => _loading = true);
    try {
      await ClienteSupabaseService.instance.declararDeudaInformal(
        tieneDeuda: _tieneDeuda,
        monto: double.tryParse(_montoController.text) ?? 0,
        entidad: _entidadController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Declaración enviada. Tu asesor fue notificado.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        _montoController.clear();
        _entidadController.clear();
        await _loadHistorial();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deuda Informal'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '¿Tiene deuda con panderos, juntas o prestamistas?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            value: _tieneDeuda,
            activeThumbColor: const Color(0xFFEC0000),
            title: Text(_tieneDeuda ? 'Sí' : 'No'),
            onChanged: (v) => setState(() => _tieneDeuda = v),
          ),
          if (_tieneDeuda) ...[
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto aproximado (S/)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _entidadController,
              decoration: const InputDecoration(
                labelText: 'Entidad (texto libre)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('GUARDAR DECLARACIÓN'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Historial de declaraciones',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          ..._historial.map((d) => Card(
                child: ListTile(
                  title: Text(d['tiene_deuda'] == true ? 'Con deuda' : 'Sin deuda'),
                  subtitle: Text(d['entidad'] ?? ''),
                  trailing: Text(Formatters.money(
                    (d['monto_aproximado'] as num?)?.toDouble() ?? 0,
                  )),
                ),
              )),
        ],
      ),
    );
  }
}
