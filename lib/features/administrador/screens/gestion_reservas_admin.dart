import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool cargando = true;
  String filtroEstado = 'Todas';

  final List<String> estados = [
    'Todas',
    'Pendiente',
    'Confirmada',
    'Atendida',
    'Cancelada',
  ];

  @override
  void initState() {
    super.initState();
    cargarReservas();
  }

  @override
  void dispose() {
    buscarController.dispose();
    super.dispose();
  }

  Future<void> cargarReservas() async {
    if (mounted) {
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

    final fecha = reserva['fecha']?.toString() ?? '';
    final hora = reserva['hora']?.toString() ?? '';

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
              Text('Fecha: ${reserva['fecha']}  |  Hora: ${reserva['hora']}'),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver detalles',
                  style: TextStyle(color: verde, fontWeight: FontWeight.bold),
                ),
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
