class Servicio {
  final int id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int? duracionMinutos;
  final bool activo;

  Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.duracionMinutos,
    required this.activo,
  });

  factory Servicio.fromMap(Map<String, dynamic> mapa) {
    return Servicio(
      id: (mapa['id'] as num).toInt(),
      nombre: mapa['nombre'] as String,
      descripcion: mapa['descripcion'] as String?,
      precio: (mapa['precio'] as num?)?.toDouble() ?? 0.0,
      duracionMinutos:
          (mapa['duracion_minutos'] as num?)?.toInt(),
      activo: mapa['activo'] as bool? ?? true,
    );
  }
}