import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionProductosScreen extends StatefulWidget {
  const GestionProductosScreen({super.key});

  @override
  State<GestionProductosScreen> createState() => _GestionProductosScreenState();
}

class _GestionProductosScreenState extends State<GestionProductosScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final supabase = Supabase.instance.client;
  final busquedaController = TextEditingController();
  final nombreController = TextEditingController();
  final descripcionController = TextEditingController();
  final categoriaController = TextEditingController();
  final precioController = TextEditingController();
  final stockController = TextEditingController();
  final imagenController = TextEditingController();

  RealtimeChannel? _canalProductos;

  List<Map<String, dynamic>> productos = [];

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

  String filtroEstado = 'Todos';
  final formKey = GlobalKey<FormState>();

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
      final datos = await supabase.rpc('listar_productos_admin');

      if (!mounted) return;

      setState(() {
        productos = List<Map<String, dynamic>>.from(datos);
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
        .channel('productos-administrador')
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

  int get totalProductos => productos.length;

  int get productosActivos =>
      productos.where((p) => p['activo'] == true).length;

  int get productosInactivos =>
      productos.where((p) => p['activo'] != true).length;

  int get productosAgotados => productos.where((p) {
    final stock = p['stock'];
    return p['activo'] == true && stock is num && stock <= 0;
  }).length;

  List<Map<String, dynamic>> get productosFiltrados {
    final busqueda = textoBusqueda.trim().toLowerCase();

    return productos.where((producto) {
      final nombre = producto['nombre']?.toString().toLowerCase() ?? '';
      final categoria = producto['categoria']?.toString().toLowerCase() ?? '';

      final coincideBusqueda =
          busqueda.isEmpty ||
          nombre.contains(busqueda) ||
          categoria.contains(busqueda);

      final activo = producto['activo'] == true;

      final coincideEstado = switch (filtroEstado) {
        'Activos' => activo,
        'Inactivos' => !activo,
        'Agotados' =>
          activo && producto['stock'] is num && (producto['stock'] as num) <= 0,
        _ => true,
      };

      return coincideBusqueda && coincideEstado;
    }).toList();
  }

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalProductos != null) {
      supabase.removeChannel(_canalProductos!);
    }
    nombreController.dispose();
    descripcionController.dispose();
    categoriaController.dispose();
    precioController.dispose();
    stockController.dispose();
    imagenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text(
          'Gestión de productos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarProductos,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: cargarProductos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : contenidoPrincipal(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
    );
  }

  Widget contenidoPrincipal() {
    final lista = productosFiltrados;

    return RefreshIndicator(
      color: verde,
      onRefresh: cargarProductos,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Inventario de PetCare',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Administra los productos disponibles en la tienda.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 22),

          const Text(
            'Resumen de productos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              tarjetaIndicador(
                'Total',
                totalProductos,
                Icons.inventory_2_rounded,
                verde,
              ),
              const SizedBox(width: 10),
              tarjetaIndicador(
                'Activos',
                productosActivos,
                Icons.check_circle_rounded,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tarjetaIndicador(
                'Inactivos',
                productosInactivos,
                Icons.visibility_off_rounded,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              tarjetaIndicador(
                'Agotados',
                productosAgotados,
                Icons.remove_shopping_cart_rounded,
                Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 24),

          TextField(
            controller: busquedaController,
            onChanged: (valor) {
              setState(() {
                textoBusqueda = valor;
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o categoría...',
              prefixIcon: const Icon(Icons.search, color: verde),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Todos', 'Activos', 'Inactivos', 'Agotados'].map((
                filtro,
              ) {
                final seleccionado = filtroEstado == filtro;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filtro),
                    selected: seleccionado,
                    selectedColor: verdeClaro,
                    labelStyle: TextStyle(
                      color: seleccionado ? verde : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() {
                        filtroEstado = filtro;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Productos (${lista.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 12),

          if (lista.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text('No se encontraron productos.'),
              ),
            )
          else
            ...lista.map(tarjetaProducto),
        ],
      ),
    );
  }

  Widget tarjetaIndicador(
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EEE9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: color, size: 21),
            ),
            const SizedBox(height: 9),
            Text(
              cantidad.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaProducto(Map<String, dynamic> producto) {
    final nombre = producto['nombre']?.toString() ?? 'Sin nombre';
    final descripcion =
        producto['descripcion']?.toString() ?? 'Sin descripción';
    final categoria = producto['categoria']?.toString() ?? 'Sin categoría';
    final imagenUrl = producto['imagen_url']?.toString() ?? '';
    final precio = producto['precio'];
    final stock = producto['stock'] ?? 0;
    final activo = producto['activo'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagenUrl.isNotEmpty
                  ? Image.network(
                      imagenUrl,
                      width: 85,
                      height: 85,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => contenedorImagen(),
                    )
                  : contenedorImagen(),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoria,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    precio == null
                        ? 'Precio no definido'
                        : 'Bs. ${precio.toString()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  Text(
                    'Stock: $stock',
                    style: TextStyle(
                      fontSize: 12,
                      color: stock is num && stock <= 0
                          ? Colors.red
                          : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        activo ? Icons.check_circle : Icons.visibility_off,
                        size: 15,
                        color: activo ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activo ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Acciones del producto',
              icon: const Icon(Icons.more_vert, color: verde),
              onSelected: (opcion) {
                if (opcion == 'editar') {
                  mostrarFormulario(producto: producto);
                } else if (opcion == 'stock') {
                  actualizarStock(producto);
                } else if (opcion == 'estado') {
                  cambiarEstadoProducto(producto);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: verde),
                      SizedBox(width: 10),
                      Text('Editar producto'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'stock',
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: verde),
                      SizedBox(width: 10),
                      Text('Actualizar stock'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'estado',
                  child: Row(
                    children: [
                      Icon(
                        activo ? Icons.visibility_off : Icons.visibility,
                        color: activo ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Text(activo ? 'Desactivar producto' : 'Activar producto'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget contenedorImagen() {
    return Container(
      width: 85,
      height: 85,
      color: verdeClaro,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, size: 38, color: verde),
    );
  }

  Future<void> guardarProducto({int? productoId}) async {
    if (!formKey.currentState!.validate()) return;

    final nombre = nombreController.text.trim();
    final descripcion = descripcionController.text.trim();
    final categoria = categoriaController.text.trim();
    final precioTexto = precioController.text.trim();
    final stockTexto = stockController.text.trim();
    final imagen = imagenController.text.trim();

    final precio = precioTexto.isEmpty ? null : double.tryParse(precioTexto);
    final stock = int.tryParse(stockTexto);

    if (precioTexto.isNotEmpty && precio == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El precio no es válido.')));
      return;
    }

    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El stock debe ser un número válido.')),
      );
      return;
    }

    try {
      if (productoId == null) {
        await supabase.rpc(
          'crear_producto_admin',
          params: {
            'p_nombre': nombre,
            'p_descripcion': descripcion.isEmpty ? null : descripcion,
            'p_categoria': categoria.isEmpty ? null : categoria,
            'p_precio': precio,
            'p_stock': stock,
            'p_imagen_url': imagen.isEmpty ? null : imagen,
          },
        );
      } else {
        await supabase.rpc(
          'editar_producto_admin',
          params: {
            'p_producto_id': productoId,
            'p_nombre': nombre,
            'p_descripcion': descripcion.isEmpty ? null : descripcion,
            'p_categoria': categoria.isEmpty ? null : categoria,
            'p_precio': precio,
            'p_imagen_url': imagen.isEmpty ? null : imagen,
          },
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
      limpiarFormulario();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productoId == null
                ? 'Producto registrado correctamente.'
                : 'Producto actualizado correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await cargarProductos(mostrarCarga: false);
    } catch (e) {
      debugPrint('ERROR AL GUARDAR PRODUCTO: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el producto.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> actualizarStock(Map<String, dynamic> producto) async {
    final stockControllerDialog = TextEditingController(
      text: producto['stock']?.toString() ?? '0',
    );

    final formKeyStock = GlobalKey<FormState>();

    final nuevoStock = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Actualizar stock',
            style: TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKeyStock,
            child: TextFormField(
              controller: stockControllerDialog,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad disponible',
                prefixIcon: Icon(Icons.warehouse, color: verde),
              ),
              validator: (valor) {
                final cantidad = int.tryParse(valor ?? '');
                if (cantidad == null || cantidad < 0) {
                  return 'Ingresa una cantidad válida';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKeyStock.currentState!.validate()) return;

                Navigator.pop(
                  dialogContext,
                  int.parse(stockControllerDialog.text.trim()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );

    stockControllerDialog.dispose();

    if (nuevoStock == null || !mounted) return;

    try {
      await supabase.rpc(
        'actualizar_stock_producto_admin',
        params: {
          'p_producto_id': int.parse(producto['id'].toString()),
          'p_stock': nuevoStock,
        },
      );

      if (!mounted) return;

      await cargarProductos(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock actualizado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL ACTUALIZAR STOCK: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el stock.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> cambiarEstadoProducto(Map<String, dynamic> producto) async {
    final activo = producto['activo'] == true;
    final nuevoEstado = !activo;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nuevoEstado ? 'Activar producto' : 'Desactivar producto'),
        content: Text(
          nuevoEstado
              ? '¿Deseas activar "${producto['nombre']}"?'
              : '¿Deseas desactivar "${producto['nombre']}"? No aparecerá en la tienda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
            ),
            child: Text(nuevoEstado ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await supabase.rpc(
        'cambiar_estado_producto_admin',
        params: {
          'p_producto_id': int.parse(producto['id'].toString()),
          'p_activo': nuevoEstado,
        },
      );

      if (!mounted) return;

      await cargarProductos(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado
                ? 'Producto activado correctamente.'
                : 'Producto desactivado correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL CAMBIAR ESTADO DEL PRODUCTO: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el estado del producto.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void limpiarFormulario() {
    nombreController.clear();
    descripcionController.clear();
    categoriaController.clear();
    precioController.clear();
    stockController.clear();
    imagenController.clear();
  }

  void mostrarFormulario({Map<String, dynamic>? producto}) {
    final esEdicion = producto != null;

    limpiarFormulario();

    if (esEdicion) {
      nombreController.text = producto['nombre']?.toString() ?? '';
      descripcionController.text = producto['descripcion']?.toString() ?? '';
      categoriaController.text = producto['categoria']?.toString() ?? '';
      precioController.text = producto['precio']?.toString() ?? '';
      stockController.text = producto['stock']?.toString() ?? '0';
      imagenController.text = producto['imagen_url']?.toString() ?? '';
    } else {
      stockController.text = '0';
    }

    formKey.currentState?.reset();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            esEdicion ? 'Editar producto' : 'Nuevo producto',
            style: const TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    campoFormulario(
                      controller: nombreController,
                      etiqueta: 'Nombre del producto',
                      icono: Icons.inventory_2,
                      validador: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Ingresa el nombre del producto';
                        }
                        return null;
                      },
                    ),
                    campoFormulario(
                      controller: descripcionController,
                      etiqueta: 'Descripción',
                      icono: Icons.description,
                      maxLineas: 3,
                    ),
                    campoFormulario(
                      controller: categoriaController,
                      etiqueta: 'Categoría',
                      icono: Icons.category,
                    ),
                    campoFormulario(
                      controller: precioController,
                      etiqueta: 'Precio en Bs.',
                      icono: Icons.payments,
                      tipo: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validador: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return null;
                        }
                        final precio = double.tryParse(valor.trim());
                        if (precio == null || precio < 0) {
                          return 'Ingresa un precio válido';
                        }
                        return null;
                      },
                    ),
                    if (!esEdicion)
                      campoFormulario(
                        controller: stockController,
                        etiqueta: 'Stock inicial',
                        icono: Icons.warehouse,
                        tipo: TextInputType.number,
                        validador: (valor) {
                          final stock = int.tryParse(valor ?? '');
                          if (stock == null || stock < 0) {
                            return 'Ingresa un stock válido';
                          }
                          return null;
                        },
                      ),
                    campoFormulario(
                      controller: imagenController,
                      etiqueta: 'URL de la imagen (opcional)',
                      icono: Icons.image,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                guardarProducto(
                  productoId: esEdicion
                      ? int.parse(producto['id'].toString())
                      : null,
                );
              },
              icon: const Icon(Icons.save),
              label: Text(esEdicion ? 'Guardar cambios' : 'Registrar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget campoFormulario({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    TextInputType tipo = TextInputType.text,
    String? Function(String?)? validador,
    int maxLineas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        maxLines: maxLineas,
        validator: validador,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono, color: verde),
          filled: true,
          fillColor: fondo,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E8E1)),
          ),
        ),
      ),
    );
  }
}
