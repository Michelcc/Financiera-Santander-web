import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../services/calculadora_credito.dart';
import '../../services/cliente_supabase_service.dart';
import 'mis_solicitudes_screen.dart';

class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key});

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  double _monto = 10000;
  double _plazo = 12;
  bool _conSeguro = false;
  bool _enviando = false;

  Future<void> _solicitar() async {
    setState(() => _enviando = true);
    try {
      final resultado = await ClienteSupabaseService.instance.crearSolicitud(
        monto: _monto,
        plazoMeses: _plazo.round(),
        conSeguro: _conSeguro,
      );
      if (!mounted) return;
      final exp = resultado['expediente_numero'] ?? resultado['expediente'];
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: Text(
            'Su solicitud fue registrada en el sistema.\n'
            'Expediente: $exp\n'
            'Su asesor y el supervisor fueron notificados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MisSolicitudesScreen(),
                  ),
                );
              },
              child: const Text('Ver mis solicitudes'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = CalculadoraCredito.simular(
      monto: _monto,
      plazoMeses: _plazo.round(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Crédito'),
        backgroundColor: const Color(0xFFEC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'TEA referencial: 43.92 % sin seguro · 40.92 % con seguro',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text('Monto: ${Formatters.money(_monto)}'),
          Slider(
            value: _monto,
            min: 500,
            max: 150000,
            divisions: 100,
            activeColor: const Color(0xFFEC0000),
            label: Formatters.money(_monto),
            onChanged: (v) => setState(() => _monto = v),
          ),
          Text('Plazo: ${_plazo.round()} meses'),
          Slider(
            value: _plazo,
            min: 3,
            max: 60,
            divisions: 57,
            activeColor: const Color(0xFFEC0000),
            label: '${_plazo.round()}',
            onChanged: (v) => setState(() => _plazo = v),
          ),
          SwitchListTile(
            title: const Text('Incluir seguro desgravamen'),
            subtitle: const Text('TEA preferencial 40.92 %'),
            value: _conSeguro,
            activeThumbColor: const Color(0xFFEC0000),
            onChanged: (v) => setState(() => _conSeguro = v),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _resultRow('Cuota mensual', Formatters.money(resultado.cuotaMensual)),
                  _resultRow('Total a pagar', Formatters.money(resultado.totalPagar)),
                  _resultRow(
                    'Costo financiero',
                    Formatters.money(resultado.costoFinanciero),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _enviando ? null : _solicitar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _enviando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('SOLICITAR CRÉDITO'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
