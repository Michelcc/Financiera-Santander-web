/// Ciclo de vida de visita (diagrama de estados UML).
enum EstadoVisita {
  pendiente,
  visitadoLocal,
  sincronizado,
}

extension EstadoVisitaX on EstadoVisita {
  String get label => switch (this) {
        EstadoVisita.pendiente => 'Pendiente',
        EstadoVisita.visitadoLocal => 'Visitado (local)',
        EstadoVisita.sincronizado => 'Sincronizado',
      };

  static EstadoVisita fromSyncedFlag(int synced) =>
      synced == 1 ? EstadoVisita.sincronizado : EstadoVisita.visitadoLocal;
}
