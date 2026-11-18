import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/utils/fechas.dart';

class GestionReservasAdminScreen extends StatefulWidget {
  const GestionReservasAdminScreen({super.key});

  @override
  State<GestionReservasAdminScreen> createState() =>
      _GestionReservasAdminScreenState();
}

class _GestionReservasAdminScreenState
    extends State<GestionReservasAdminScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final supabase = Supabase.instance.client;
  final TextEditingController buscarController = TextEditingController();

  List<Map<String, dynamic>> reservas = [];
  final Set<int> reservasActualizando = {};
  RealtimeChannel? _canalReservas;
  bool cargando = true;
  String filtroEstado = 'Todas';

  final List<String> estados = [
    'Todas',
    'Pendiente',
    'Confirmada',
    'Atendida',
    'Cancelada',
  ];
  void escucharReservas() {
    _canalReservas = supabase
        .channel('reservas-administrador')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservas',
          callback: (payload) {
            cargarReservas(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  @override
  void initState() {
    super.initState();
    cargarReservas();
    escucharReservas();
  }

  @override
  void dispose() {
    buscarController.dispose();
    if (_canalReservas != null) {
      supabase.removeChannel(_canalReservas!);
    }
    super.dispose();
  }

  Future<void> cargarReservas({bool mostrarCarga = true}) async {
    if (mounted && mostrarCarga) {
      setState(() => cargando = true);
    }

    try {
      final respuesta = await supabase.rpc('listar_reservas_admin');

      if (!mounted) return;

      setState(() {
        reservas = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reservas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> cambiarEstadoReserva(
    Map<String, dynamic> reserva,
    String nuevoEstado,
  ) async {
    final id = int.parse(reserva['id'].toString());

    setState(() {
      reservasActualizando.add(id);
    });

    try {
      await supabase.rpc(
        'cambiar_estado_reserva_admin',
        params: {'p_reserva_id': id, 'p_estado': nuevoEstado},
      );

      await cargarReservas(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reserva actualizada a: $nuevoEstado'),
          backgroundColor: verde,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la reserva: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          reservasActualizando.remove(id);
        });
      }
    }
  }

  int get totalReservas => reservas.length;

  int contarEstado(String estado) {
    return reservas
        .where(
          (reserva) =>
              reserva['estado']?.toString().toLowerCase() ==
              estado.toLowerCase(),
        )
        .length;
  }

  List<Map<String, dynamic>> get reservasFiltradas {
    final busqueda = buscarController.text.toLowerCase().trim();

    return reservas.where((reserva) {
      final estado = reserva['estado']?.toString() ?? '';

      final cliente = reserva['nombre']?.toString().toLowerCase() ?? '';
      final mascota =
          (reserva['nombre_mascota'] ?? reserva['mascota'])
              ?.toString()
              .toLowerCase() ??
          '';
      final servicio = reserva['servicio']?.toString().toLowerCase() ?? '';
      final telefono = reserva['telefono']?.toString().toLowerCase() ?? '';

      final coincideEstado = filtroEstado == 'Todas' || estado == filtroEstado;

      final coincideBusqueda =
          busqueda.isEmpty ||
          cliente.contains(busqueda) ||
          mascota.contains(busqueda) ||
          servicio.contains(busqueda) ||
          telefono.contains(busqueda);

      return coincideEstado && coincideBusqueda;
    }).toList();
  }

  Color colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmada':
        return Colors.blue;
      case 'atendida':
        return verde;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void mostrarDetalles(Map<String, dynamic> reserva) {
    final mascota =
        reserva['nombre_mascota'] ?? reserva['mascota'] ?? 'No especificada';

    final especie = reserva['especie_mascota'] ?? 'No especificada';

    final fecha = Fechas.formatearFecha(reserva['fecha']);
    final hora = Fechas.formatearHora(reserva['hora']);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Detalles de la reserva',
            style: TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                detalle('Número de reserva', '#${reserva['id']}'),
                detalle('Cliente', reserva['nombre'] ?? ''),
                detalle('Teléfono', reserva['telefono'] ?? ''),
                detalle('Mascota', mascota),
                detalle('Especie', especie),
                detalle('Servicio', reserva['servicio'] ?? 'No especificado'),
                detalle('Fecha', fecha),
                detalle('Hora', hora),
                detalle('Personas', '${reserva['personas'] ?? 0}'),
                detalle('Estado', reserva['estado'] ?? ''),
                detalle(
                  'Comentario',
                  reserva['comentario']?.toString().isNotEmpty == true
                      ? reserva['comentario']
                      : 'Sin comentarios',
                ),
                detalle(
                  'ID del propietario',
                  reserva['usuario_id']?.toString() ?? 'No disponible',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar', style: TextStyle(color: verde)),
            ),
          ],
        );
      },
    );
  }

  Widget tarjetaIndicador({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 25),
            const SizedBox(height: 7),
            Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget detalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, color: verde),
          ),
          const SizedBox(height: 3),
          Text(valor),
        ],
      ),
    );
  }

  Widget tarjetaReserva(Map<String, dynamic> reserva) {
    final estado = reserva['estado']?.toString() ?? 'Sin estado';
    final id = int.parse(reserva['id'].toString());
    final actualizando = reservasActualizando.contains(id);

    final mascota =
        reserva['nombre_mascota'] ?? reserva['mascota'] ?? 'Sin mascota';

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => mostrarDetalles(reserva),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: verdeClaro,
                    child: Icon(Icons.calendar_month, color: verde),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reserva['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Reserva #${reserva['id']}',
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
                      estado,
                      style: TextStyle(
                        color: colorEstado(estado),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Mascota: $mascota'),
              const SizedBox(height: 5),
              Text('Servicio: ${reserva['servicio'] ?? 'No especificado'}'),
              const SizedBox(height: 5),
              Text(
                'Fecha: ${Fechas.formatearFechaHora(reserva['fecha'], reserva['hora'])}',
              ),
              const SizedBox(height: 8),
              const Divider(height: 24),

              Row(
                children: [
                  const Text(
                    'Cambiar estado:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (actualizando)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: verde,
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      tooltip: 'Cambiar estado',
                      onSelected: (nuevoEstado) {
                        cambiarEstadoReserva(reserva, nuevoEstado);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'Pendiente',
                          child: Text('Pendiente'),
                        ),
                        const PopupMenuItem(
                          value: 'Confirmada',
                          child: Text('Confirmar reserva'),
                        ),
                        const PopupMenuItem(
                          value: 'Atendida',
                          child: Text('Marcar como atendida'),
                        ),
                        const PopupMenuItem(
                          value: 'Cancelada',
                          child: Text('Cancelar reserva'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: verdeClaro,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cambiar',
                              style: TextStyle(
                                color: verde,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_drop_down, color: verde),
                          ],
                        ),
                      ),
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
    final lista = reservasFiltradas;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'Gestión de reservas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarReservas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : RefreshIndicator(
              onRefresh: cargarReservas,
              color: verde,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Pendientes',
                        cantidad: contarEstado('Pendiente'),
                        icono: Icons.pending_actions,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Confirmadas',
                        cantidad: contarEstado('Confirmada'),
                        icono: Icons.event_available,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Atendidas',
                        cantidad: contarEstado('Atendida'),
                        icono: Icons.check_circle,
                        color: verde,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Canceladas',
                        cantidad: contarEstado('Cancelada'),
                        icono: Icons.event_busy,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: buscarController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente, mascota o servicio...',
                      prefixIcon: const Icon(Icons.search, color: verde),
                      suffixIcon: buscarController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                buscarController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filtrar por estado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: filtroEstado,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: estados.map((estado) {
                      return DropdownMenuItem(
                        value: estado,
                        child: Text(estado),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => filtroEstado = valor);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reservas encontradas: ${lista.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (lista.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 55, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No se encontraron reservas.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...lista.map(tarjetaReserva),
                ],
              ),
            ),
    );
  }
}
