import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GestionPedidosAdminScreen extends StatefulWidget {
  const GestionPedidosAdminScreen({super.key});

  @override
  State<GestionPedidosAdminScreen> createState() =>
      _GestionPedidosAdminScreenState();
}

class _GestionPedidosAdminScreenState extends State<GestionPedidosAdminScreen> {
  final db = Supabase.instance.client;

  List<Map<String, dynamic>> pedidos = [];
  bool cargando = true;
  String filtro = 'todos';
  String? error;
  Map<String, String> telefonosClientes = {};

  final List<String> estados = [
    'pendiente',
    'confirmado',
    'preparando',
    'enviado',
    'entregado',
    'cancelado',
  ];

  @override
  void initState() {
    super.initState();
    cargarPedidos();
  }

  Future<void> cargarPedidos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final respuesta = await db
          .from('pedidos')
          .select('''
          id,
          usuario_id,
          fecha,
          total,
          estado,
          detalle_pedido(
            id,
            cantidad,
            precio_unitario,
            subtotal,
            productos(nombre)
          )
        ''')
          .order('fecha', ascending: false);

      final lista = List<Map<String, dynamic>>.from(respuesta);

      final idsUsuarios = lista
          .map((p) => p['usuario_id'].toString())
          .toSet()
          .toList();

      final nombres = <String, String>{};
      telefonosClientes = {};

      if (idsUsuarios.isNotEmpty) {
        final perfiles = await db
            .from('perfiles')
            .select('id, nombre, telefono')
            .inFilter('id', idsUsuarios);

        for (final perfil in perfiles) {
          final id = perfil['id'].toString();

          nombres[id] = perfil['nombre']?.toString() ?? 'Cliente';
          telefonosClientes[id] = perfil['telefono']?.toString() ?? '';
        }
      }

      for (final pedido in lista) {
        final usuarioId = pedido['usuario_id'].toString();

        pedido['cliente_nombre'] = nombres[usuarioId] ?? 'Cliente';
        pedido['cliente_telefono'] = telefonosClientes[usuarioId] ?? '';
      }

      if (!mounted) return;

      setState(() {
        pedidos = lista;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        cargando = false;
      });
    }
  }

  Future<void> contactarWhatsApp(Map<String, dynamic> pedido) async {
    try {
      final telefono = pedido['cliente_telefono']?.toString() ?? '';

      if (telefono.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El cliente todavía no tiene un teléfono registrado.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pedidoId = pedido['id'];
      final nombre = pedido['cliente_nombre'];
      final total = pedido['total'];

      final mensaje =
          '''
Hola $nombre, te contactamos de PetCare Santa Cruz.

Hemos recibido tu pedido #$pedidoId por un total de Bs $total.

Queremos coordinar contigo el pago mediante QR, transferencia bancaria o efectivo.

¡Gracias por confiar en PetCare!
''';

      final enlace = Uri.parse(
        'https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}',
      );

      final abierto = await launchUrl(
        enlace,
        mode: LaunchMode.externalApplication,
      );

      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al abrir WhatsApp: $e')));
    }
  }

  Future<void> actualizarEstado(int pedidoId, String nuevoEstado) async {
    try {
      await db.rpc(
        'actualizar_estado_pedido',
        params: {'p_pedido_id': pedidoId, 'p_nuevo_estado': nuevoEstado},
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado del pedido actualizado.'),
          backgroundColor: Colors.green,
        ),
      );

      await cargarPedidos();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get pedidosFiltrados {
    if (filtro == 'todos') return pedidos;

    return pedidos.where((p) => p['estado'] == filtro).toList();
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'preparando':
        return Colors.purple;
      case 'enviado':
        return Colors.indigo;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String textoEstado(String estado) {
    if (estado.isEmpty) return 'Sin estado';

    return estado[0].toUpperCase() + estado.substring(1);
  }

  String formatoFecha(dynamic valor) {
    final fecha = DateTime.parse(valor.toString()).toLocal();

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio - $hora:$minuto';
  }

  void mostrarDetalle(Map<String, dynamic> pedido) {
    final detalles = List<Map<String, dynamic>>.from(
      pedido['detalle_pedido'] ?? [],
    );

    String estadoSeleccionado = pedido['estado'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Pedido #${pedido['id']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cliente: ${pedido['cliente_nombre']}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatoFecha(pedido['fecha']),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Divider(height: 30),
                      const Text(
                        'Productos del pedido',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (detalles.isEmpty)
                        const Text('No hay productos registrados.')
                      else
                        ...detalles.map((detalle) {
                          final producto = detalle['productos'];

                          final nombre = producto is Map
                              ? producto['nombre']?.toString() ?? 'Producto'
                              : 'Producto';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${detalle['cantidad']} unidades',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Bs ${detalle['subtotal']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const Divider(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total del pedido',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Bs ${pedido['total']}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => contactarWhatsApp(pedido),
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('Contactar por WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Actualizar estado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: estadoSeleccionado,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: estados.map((estado) {
                          return DropdownMenuItem(
                            value: estado,
                            child: Text(textoEstado(estado)),
                          );
                        }).toList(),
                        onChanged: pedido['estado'] == 'cancelado'
                            ? null
                            : (valor) {
                                if (valor != null) {
                                  setModalState(() {
                                    estadoSeleccionado = valor;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              estadoSeleccionado == pedido['estado'] ||
                                  pedido['estado'] == 'cancelado'
                              ? null
                              : () => actualizarEstado(
                                  (pedido['id'] as num).toInt(),
                                  estadoSeleccionado,
                                ),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar cambios'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget construirPedido(Map<String, dynamic> pedido) {
    final estado = pedido['estado'].toString();
    final detalles = List<Map<String, dynamic>>.from(
      pedido['detalle_pedido'] ?? [],
    );

    final cantidadProductos = detalles.fold<int>(
      0,
      (total, detalle) => total + ((detalle['cantidad'] as num?)?.toInt() ?? 0),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => mostrarDetalle(pedido),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.teal,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${pedido['id']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          pedido['cliente_nombre'].toString(),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorEstado(estado).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textoEstado(estado),
                      style: TextStyle(
                        color: colorEstado(estado),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatoFecha(pedido['fecha']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$cantidadProductos unidades',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'Bs ${pedido['total']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.teal,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de pedidos'),
        actions: [
          IconButton(
            onPressed: cargarPedidos,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar pedidos',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: filtro,
              decoration: InputDecoration(
                labelText: 'Filtrar pedidos',
                prefixIcon: const Icon(Icons.filter_list_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'todos',
                  child: Text('Todos los pedidos'),
                ),
                ...estados.map(
                  (estado) => DropdownMenuItem(
                    value: estado,
                    child: Text(textoEstado(estado)),
                  ),
                ),
              ],
              onChanged: (valor) {
                if (valor != null) {
                  setState(() {
                    filtro = valor;
                  });
                }
              },
            ),
          ),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 45,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se pudieron cargar los pedidos.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: cargarPedidos,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : pedidosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay pedidos para mostrar.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: cargarPedidos,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pedidosFiltrados.length,
                      itemBuilder: (context, index) {
                        return construirPedido(pedidosFiltrados[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
