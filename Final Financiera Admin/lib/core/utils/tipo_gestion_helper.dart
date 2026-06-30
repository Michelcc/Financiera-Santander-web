/// Normaliza tipos de gestión (con/sin tildes, mayúsculas).
class TipoGestionHelper {
  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  static bool matchesFilter(String tipoGestion, String filter) {
    if (filter == 'Todos') return true;
    if (filter == 'Nuevos') {
      return normalize(tipoGestion).contains('nueva');
    }
    return normalize(tipoGestion) == normalize(filter);
  }

  static const filterChips = [
    'Todos',
    'Nuevos',
    'Mora',
    'Renovación',
    'Ampliación',
  ];
}
