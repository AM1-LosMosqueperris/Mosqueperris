import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MisPedidosScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const MisPedidosScreen({super.key, this.onOpenMenu});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color fondo = Color(0xFFF7FAF6);

  final db = Supabase.instance.client;

  List<Map<String, dynamic>> pedidos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarPedidos();
  }

  Future<void> cargarPedidos() async {
    try {
      final usuario = db.auth.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión activa');
      }

      final datos = await db
          .from('pedidos')
          .select('''
            id,
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
          .eq('usuario_id', usuario.id)
          .order('fecha', ascending: false);

      if (!mounted) return;

      setState(() {
        pedidos = List<Map<String, dynamic>>.from(datos);
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR PEDIDOS: $e');

      if (!mounted) return;

      setState(() => cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar tus pedidos.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String fechaBonita(dynamic valor) {
    if (valor == null) return 'Fecha no disponible';

    try {
      final fecha = DateTime.parse(valor.toString()).toLocal();

      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (_) {
      return valor.toString();
    }
  }

  String dinero(dynamic valor) {
    final numero = double.tryParse(valor.toString()) ?? 0;
    return 'Bs ${numero.toStringAsFixed(2)}';
  }

  Color colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'enviado':
        return Colors.blue;
      case 'preparando':
        return Colors.deepOrange;
      case 'confirmado':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String nombreEstado(String estado) {
    if (estado.isEmpty) return 'Pendiente';

    return estado[0].toUpperCase() + estado.substring(1);
  }

  void mostrarDetalle(Map<String, dynamic> pedido) {
    final detalles = List<Map<String, dynamic>>.from(
      pedido['detalle_pedido'] ?? [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: verde, size: 27),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pedido #${pedido['id']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: detalles.isEmpty
                    ? const Center(child: Text('No hay productos registrados.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: detalles.length,
                        separatorBuilder: (_, _) => const Divider(height: 25),
                        itemBuilder: (context, index) {
                          final item = detalles[index];
                          final producto = item['productos'];

                          final nombre = producto is Map
                              ? producto['nombre']?.toString() ?? 'Producto'
                              : 'Producto';

                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F5ED),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: verde,
                                ),
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
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${item['cantidad']} unidades × '
                                      '${dinero(item['precio_unitario'])}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                dinero(item['subtotal']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: verde,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total del pedido',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dinero(pedido['total']),
                      style: const TextStyle(
                        color: verde,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget tarjetaPedido(Map<String, dynamic> pedido) {
    final estado = pedido['estado']?.toString() ?? 'pendiente';
    final detalles = List<Map<String, dynamic>>.from(
      pedido['detalle_pedido'] ?? [],
    );

    final cantidad = detalles.fold<int>(
      0,
      (total, item) => total + (int.tryParse(item['cantidad'].toString()) ?? 0),
    );

    final color = colorEstado(estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8EEE9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => mostrarDetalle(pedido),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: verde,
                    size: 25,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pedido #${pedido['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nombreEstado(estado),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    fechaBonita(pedido['fecha']),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 15,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$cantidad unidades',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${detalles.length} productos diferentes',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    dinero(pedido['total']),
                    style: const TextStyle(
                      color: verde,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_ios, size: 13, color: verde),
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
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu),
              ),
        title: const Text(
          'Mis pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: cargarPedidos,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : RefreshIndicator(
              color: verde,
              onRefresh: cargarPedidos,
              child: pedidos.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5ED),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 48,
                                      color: verde,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Todavía no tienes pedidos',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: verde,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Cuando realices una compra en nuestra tienda, '
                                    'podrás consultar aquí todos sus detalles.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [verde, Color(0xFF258456)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                color: Colors.white,
                                size: 35,
                              ),
                              SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tus compras en PetCare',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Consulta tus pedidos y el estado de cada uno.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Historial de compras (${pedidos.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF26352C),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...pedidos.map(tarjetaPedido),
                      ],
                    ),
            ),
    );
  }
}
