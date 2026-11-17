import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TiendaScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const TiendaScreen({super.key, this.onOpenMenu});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  final supabase = Supabase.instance.client;
  final buscarController = TextEditingController();

  RealtimeChannel? _canalProductos;

  bool cargando = true;
  String? error;

  List<Map<String, dynamic>> productos = [];

  static const Color verde = Color(0xFF17623F);

  @override
  void initState() {
    super.initState();
    cargarProductos();
    escucharCambios();
  }

  Future<void> cargarProductos({bool mostrarCarga = true}) async {
    if (!mounted) return;

    setState(() {
      if (mostrarCarga) cargando = true;
      error = null;
    });

    try {
      final respuesta = await supabase
          .from('productos')
          .select()
          .eq('activo', true)
          .order('nombre');

      if (!mounted) return;

      setState(() {
        productos = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR PRODUCTOS: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        error = 'No se pudieron cargar los productos.';
      });
    }
  }

  void escucharCambios() {
    _canalProductos = supabase
        .channel('tienda-productos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          callback: (payload) {
            cargarProductos(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  List<Map<String, dynamic>> get productosFiltrados {
    final texto = buscarController.text.trim().toLowerCase();

    if (texto.isEmpty) return productos;

    return productos.where((producto) {
      final nombre = producto['nombre']?.toString().toLowerCase() ?? '';
      final categoria = producto['categoria']?.toString().toLowerCase() ?? '';

      return nombre.contains(texto) || categoria.contains(texto);
    }).toList();
  }

  @override
  void dispose() {
    buscarController.dispose();

    if (_canalProductos != null) {
      supabase.removeChannel(_canalProductos!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lista = productosFiltrados;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Text('Tienda'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarProductos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar productos',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargarProductos,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Todo para tu mascota 🐾',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Descubre productos para cuidar y consentir a tus mascotas.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: buscarController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: const Icon(Icons.search, color: verde),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Nuestros productos',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 15),

            if (cargando)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator(color: verde)),
              )
            else if (error != null)
              Center(
                child: Column(
                  children: [
                    Text(error!),
                    ElevatedButton(
                      onPressed: cargarProductos,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: Text('No hay productos disponibles.')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lista.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.77,
                ),
                itemBuilder: (context, index) {
                  return _Producto(producto: lista[index]);
                },
              ),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Precios referenciales. Consulta disponibilidad.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Producto extends StatelessWidget {
  final Map<String, dynamic> producto;

  const _Producto({required this.producto});

  static const Color verde = Color(0xFF17623F);

  @override
  Widget build(BuildContext context) {
    final nombre = producto['nombre']?.toString() ?? 'Producto';
    final categoria = producto['categoria']?.toString() ?? 'General';
    final descripcion = producto['descripcion']?.toString() ?? '';
    final imagenUrl = producto['imagen_url']?.toString();
    final precio = producto['precio'];
    final stock = producto['stock'];

    final precioTexto = precio == null
        ? 'Precio no disponible'
        : 'Bs. ${precio.toString()}';

    final disponible = stock == null || (stock is num && stock > 0);

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imagenUrl != null && imagenUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imagenUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.pets,
                              size: 55,
                              color: verde,
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.pets, size: 55, color: verde),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              categoria,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              precioTexto,
              style: const TextStyle(
                color: verde,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stock == null
                  ? 'Disponibilidad por consultar'
                  : disponible
                  ? 'Stock: $stock'
                  : 'Agotado',
              style: TextStyle(
                fontSize: 11,
                color: disponible ? Colors.black54 : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
