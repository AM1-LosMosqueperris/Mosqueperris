class Producto {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? categoria;
  final double precio;
  final int stock;
  final String? imagenUrl;
  final bool activo;

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    required this.precio,
    required this.stock,
    this.imagenUrl,
    required this.activo,
  });

  factory Producto.fromMap(Map<String, dynamic> mapa) {
    return Producto(
      id: mapa['id'],
      nombre: mapa['nombre'],
      descripcion: mapa['descripcion'],
      categoria: mapa['categoria'],
      precio: (mapa['precio'] as num?)?.toDouble() ?? 0.0,
      stock: mapa['stock'] ?? 0,
      imagenUrl: mapa['imagen_url'],
      activo: mapa['activo'] ?? true,
    );
  }
}