import 'package:intl/intl.dart';

class Formatters {
  static final _money = NumberFormat.currency(locale: 'es_PE', symbol: 'S/');

  static String money(num value) => _money.format(value);

  static String documentoCensurado(String documento) {
    if (documento.length <= 4) return documento;
    return '***${documento.substring(documento.length - 3)}';
  }

  static String fecha(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
