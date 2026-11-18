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
  bool procesandoPedido = false;
  bool mostrarCarrito = false;

  String? error;

  List<Map<String, dynamic>> productos = [];

  // Producto ID -> cantidad
  final Map<int, int> carrito = {};

  static const Color verde = Color(0xFF17623F);
  static const Color fondo = Color(0xFFF7FAF6);

  int get cantidadCarrito =>
      carrito.values.fold(0, (total, cantidad) => total + cantidad);

  double get totalCarrito {
    double total = 0;

    for (final entrada in carrito.entries) {
      final producto = productos.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['id'] == entrada.key,
        orElse: () => null,
      );

      if (producto != null) {
        final precio =
            double.tryParse(producto['precio']?.toString() ?? '') ?? 0;

        total += precio * entrada.value;
      }
    }

    return total;
  }

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

  int stockProducto(Map<String, dynamic> producto) {
    return int.tryParse(producto['stock']?.toString() ?? '') ?? 0;
  }

  void agregarAlCarrito(Map<String, dynamic> producto) {
    final id = int.tryParse(producto['id'].toString());

    if (id == null) return;

    final stock = stockProducto(producto);
    final cantidadActual = carrito[id] ?? 0;

    if (stock <= cantidadActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay más unidades disponibles de este producto.'),
        ),
      );
      return;
    }

    setState(() {
      carrito[id] = cantidadActual + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto['nombre']} agregado al carrito'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void cambiarCantidad(int id, int cambio) {
    final producto = productos.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {},
    );

    if (producto.isEmpty) return;

    final cantidadActual = carrito[id] ?? 0;
    final nuevaCantidad = cantidadActual + cambio;
    final stock = stockProducto(producto);

    if (nuevaCantidad > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficiente stock disponible.')),
      );
      return;
    }

    setState(() {
      if (nuevaCantidad <= 0) {
        carrito.remove(id);
      } else {
        carrito[id] = nuevaCantidad;
      }
    });
  }

  void eliminarDelCarrito(int id) {
    setState(() {
      carrito.remove(id);
    });
  }

  Future<void> confirmarPedido() async {
    if (carrito.isEmpty || procesandoPedido) return;

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para realizar un pedido.'),
        ),
      );
      return;
    }

    setState(() {
      procesandoPedido = true;
    });

    try {
      final productosPedido = carrito.entries.map((entrada) {
        return {'producto_id': entrada.key, 'cantidad': entrada.value};
      }).toList();

      final respuesta = await supabase.rpc(
        'confirmar_pedido',
        params: {'p_productos': productosPedido},
      );

      final pedidoId = respuesta;

      if (!mounted) return;

      setState(() {
        carrito.clear();
        mostrarCarrito = false;
        procesandoPedido = false;
      });

      await cargarProductos(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: verde,
          duration: const Duration(seconds: 4),
          content: Text(
            '¡Pedido realizado correctamente! Número de pedido: $pedidoId',
          ),
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL CONFIRMAR PEDIDO: $e');

      if (!mounted) return;

      setState(() {
        procesandoPedido = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('No se pudo realizar el pedido: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        leading: mostrarCarrito
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => mostrarCarrito = false);
                },
              )
            : widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: Text(mostrarCarrito ? 'Mi carrito' : 'Tienda'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          if (!mostrarCarrito)
            IconButton(
              onPressed: () => cargarProductos(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar productos',
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Ver carrito',
                icon: Icon(
                  mostrarCarrito
                      ? Icons.storefront_outlined
                      : Icons.shopping_cart_outlined,
                ),
                onPressed: () {
                  setState(() {
                    mostrarCarrito = !mostrarCarrito;
                  });
                },
              ),
              if (cantidadCarrito > 0 && !mostrarCarrito)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 19,
                      minHeight: 19,
                    ),
                    child: Text(
                      '$cantidadCarrito',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: mostrarCarrito ? construirCarrito() : construirTienda(),
    );
  }

  Widget construirTienda() {
    final lista = productosFiltrados;

    return RefreshIndicator(
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
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                final producto = lista[index];

                return _Producto(
                  producto: producto,
                  cantidadEnCarrito:
                      carrito[int.tryParse(producto['id'].toString()) ?? -1] ??
                      0,
                  onAgregar: () => agregarAlCarrito(producto),
                );
              },
            ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Precios en bolivianos (Bs).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget construirCarrito() {
    final productosCarrito = carrito.entries
        .map((entrada) {
          return productos.firstWhere(
            (p) => p['id'] == entrada.key,
            orElse: () => {},
          );
        })
        .where((p) => p.isNotEmpty)
        .toList();

    if (productosCarrito.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 75,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 18),
              const Text(
                'Tu carrito está vacío',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrega productos de nuestra tienda para comenzar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => mostrarCarrito = false);
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Ir a la tienda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Productos seleccionados',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
              const SizedBox(height: 12),

              ...productosCarrito.map((producto) {
                final id = int.parse(producto['id'].toString());
                final cantidad = carrito[id] ?? 0;

                final precio =
                    double.tryParse(producto['precio']?.toString() ?? '') ?? 0;

                final subtotal = precio * cantidad;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5ED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              producto['imagen_url'] != null &&
                                  producto['imagen_url'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    producto['imagen_url'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.pets,
                                      color: verde,
                                      size: 35,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.pets, color: verde, size: 35),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                producto['nombre'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Bs. ${precio.toStringAsFixed(2)} c/u',
                                style: const TextStyle(
                                  color: verde,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Subtotal: Bs. ${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 7),

                              Row(
                                children: [
                                  _BotonCantidad(
                                    icono: Icons.remove,
                                    onPressed: () => cambiarCantidad(id, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '$cantidad',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _BotonCantidad(
                                    icono: Icons.add,
                                    onPressed: () => cambiarCantidad(id, 1),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Eliminar producto',
                                    onPressed: () => eliminarDelCarrito(id),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de compra',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bs. ${totalCarrito.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: verde,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: procesandoPedido ? null : confirmarPedido,
                    icon: procesandoPedido
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      procesandoPedido
                          ? 'Procesando pedido...'
                          : 'Confirmar pedido',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Producto extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onAgregar;
  final int cantidadEnCarrito;

  const _Producto({
    required this.producto,
    required this.onAgregar,
    required this.cantidadEnCarrito,
  });

  static const Color verde = Color(0xFF17623F);

  @override
  Widget build(BuildContext context) {
    final nombre = producto['nombre']?.toString() ?? 'Producto';
    final categoria = producto['categoria']?.toString() ?? 'General';
    final descripcion = producto['descripcion']?.toString() ?? '';
    final imagenUrl = producto['imagen_url']?.toString();
    final precio = producto['precio'];
    final stock = int.tryParse(producto['stock']?.toString() ?? '') ?? 0;

    final precioNumero = double.tryParse(precio?.toString() ?? '');

    final disponible = stock > cantidadEnCarrito && precioNumero != null;

    final precioTexto = precioNumero == null
        ? 'Precio no disponible'
        : 'Bs. ${precioNumero.toStringAsFixed(2)}';

    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
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
                          errorBuilder: (_, _, _) {
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
            const SizedBox(height: 8),

            Text(
              categoria,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 3),

            Text(
              nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),

            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],

            const SizedBox(height: 5),

            Text(
              precioTexto,
              style: const TextStyle(
                color: verde,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              stock <= 0 ? 'Agotado' : 'Stock: $stock',
              style: TextStyle(
                fontSize: 11,
                color: stock > 0 ? Colors.black54 : Colors.red,
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              height: 35,
              child: ElevatedButton.icon(
                onPressed: disponible ? onAgregar : null,
                icon: const Icon(Icons.add_shopping_cart, size: 15),
                label: const Text('Agregar', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonCantidad extends StatelessWidget {
  final IconData icono;
  final VoidCallback onPressed;

  const _BotonCantidad({required this.icono, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5ED),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icono, color: const Color(0xFF17623F), size: 18),
      ),
    );
  }
}
