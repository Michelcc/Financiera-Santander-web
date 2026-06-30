import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_colors.dart';
import '../../viewmodels/operaciones_viewmodel.dart';
import '../../widgets/embedded_tab_header.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/santander_app_bar.dart';
import '../../widgets/santander_loading.dart';

class OperacionesScreen extends ConsumerStatefulWidget {
  const OperacionesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<OperacionesScreen> createState() => _OperacionesScreenState();
}

class _OperacionesScreenState extends ConsumerState<OperacionesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

  String? _cuentaOrigen;
  String _tipo = 'TRF';

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  Future<void> _ejecutar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cuentaOrigen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta origen')),
      );
      return;
    }

    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    final ok = await ref.read(operacionesProvider.notifier).ejecutar(
          cuentaOrigen: _cuentaOrigen!,
          cuentaDestino: _tipo == 'TRF' ? _destinoCtrl.text.trim() : null,
          tipo: _tipo,
          monto: monto,
          concepto: _conceptoCtrl.text.trim().isEmpty
              ? null
              : _conceptoCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      _montoCtrl.clear();
      _conceptoCtrl.clear();
      _destinoCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación registrada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final err = ref.read(operacionesProvider).error ?? 'Error al operar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operacionesProvider);

    if (state.isLoading && state.cuentas.isEmpty) {
      return Scaffold(
        backgroundColor: BrandColors.surface,
        appBar: widget.embedded ? null : const SantanderAppBar(title: 'Operaciones'),
        body: Column(
          children: [
            if (widget.embedded) const EmbeddedTabHeader(title: 'Operar'),
            const Expanded(child: SantanderLoading(message: 'Cargando cuentas...')),
          ],
        ),
      );
    }

    if (_cuentaOrigen == null && state.cuentas.isNotEmpty) {
      _cuentaOrigen = state.cuentas.first.codCuentaAhorro;
    }

    return Scaffold(
      backgroundColor: BrandColors.surface,
      appBar: widget.embedded ? null : const SantanderAppBar(title: 'Operaciones'),
      body: Column(
        children: [
          if (widget.embedded) const EmbeddedTabHeader(title: 'Operar'),
          Expanded(
            child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PremiumCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nueva operación',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TRF', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'DEB', child: Text('Pago / débito')),
                      DropdownMenuItem(value: 'CRE', child: Text('Depósito / abono')),
                    ],
                    onChanged: (v) => setState(() => _tipo = v ?? 'TRF'),
                  ),
                  const SizedBox(height: 12),
                  if (state.cuentas.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _cuentaOrigen,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta origen',
                        border: OutlineInputBorder(),
                      ),
                      items: state.cuentas
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.codCuentaAhorro,
                              child: Text(c.codCuentaAhorro),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _cuentaOrigen = v),
                    )
                  else
                    const Text(
                      'Sin cuentas. Ejecuta el SQL de productos cliente en Supabase.',
                      style: TextStyle(color: BrandColors.muted),
                    ),
                  if (_tipo == 'TRF') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _destinoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta destino',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          _tipo == 'TRF' && (v == null || v.trim().isEmpty)
                              ? 'Ingresa cuenta destino'
                              : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto (S/)',
                      border: OutlineInputBorder(),
                      prefixText: 'S/ ',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                      if (n == null || n <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: state.isSaving ? null : _ejecutar,
                    style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: state.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('EJECUTAR OPERACIÓN'),
                  ),
                ],
              ),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}
