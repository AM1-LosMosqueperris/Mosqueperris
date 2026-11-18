import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionServiciosScreen extends StatefulWidget {
  const GestionServiciosScreen({super.key});

  @override
  State<GestionServiciosScreen> createState() => _GestionServiciosScreenState();
}

class _GestionServiciosScreenState extends State<GestionServiciosScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final supabase = Supabase.instance.client;
  RealtimeChannel? _canalServicios;

  List<Map<String, dynamic>> servicios = [];

  bool cargando = true;
  String? error;
  bool guardando = false;
  int get totalServicios => servicios.length;

  int get serviciosActivos =>
      servicios.where((s) => s['activo'] == true).length;

  int get serviciosInactivos =>
      servicios.where((s) => s['activo'] != true).length;

  Widget tarjetaIndicador({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              cantidad.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    cargarServicios();
    escucharCambios();
  }

  @override
  void dispose() {
    if (_canalServicios != null) {
      supabase.removeChannel(_canalServicios!);
    }
    super.dispose();
  }

  void escucharCambios() {
    _canalServicios = supabase
        .channel('servicios-administrador')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'servicios',
          callback: (payload) {
            cargarServicios(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  Future<void> cargarServicios({bool mostrarCarga = true}) async {
    if (mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final datos = await supabase.rpc('listar_servicios_admin');

      if (!mounted) return;

      setState(() {
        servicios = (datos as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        cargando = false;
        error = null;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR SERVICIOS: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar los servicios.';
        cargando = false;
      });
    }
  }

  Future<void> mostrarFormulario({Map<String, dynamic>? servicio}) async {
    final nombreController = TextEditingController(
      text: servicio?['nombre']?.toString() ?? '',
    );

    final descripcionController = TextEditingController(
      text: servicio?['descripcion']?.toString() ?? '',
    );

    final precioController = TextEditingController(
      text: servicio?['precio']?.toString() ?? '',
    );

    final duracionController = TextEditingController(
      text: servicio?['duracion_minutos']?.toString() ?? '',
    );

    final esEdicion = servicio != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, actualizarDialogo) {
            return AlertDialog(
              title: Text(esEdicion ? 'Editar servicio' : 'Nuevo servicio'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del servicio *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio (Bs)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: duracionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duración (minutos)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          final nombre = nombreController.text.trim();
                          final precioTexto = precioController.text
                              .trim()
                              .replaceAll(',', '.');
                          final duracionTexto = duracionController.text.trim();

                          if (nombre.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa el nombre del servicio.',
                                ),
                              ),
                            );
                            return;
                          }

                          final precio = precioTexto.isEmpty
                              ? null
                              : num.tryParse(precioTexto);

                          final duracion = duracionTexto.isEmpty
                              ? null
                              : int.tryParse(duracionTexto);

                          if ((precioTexto.isNotEmpty && precio == null) ||
                              (precio != null && precio < 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa un precio válido.'),
                              ),
                            );
                            return;
                          }

                          if ((duracionTexto.isNotEmpty && duracion == null) ||
                              (duracion != null && duracion <= 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa una duración válida.'),
                              ),
                            );
                            return;
                          }

                          actualizarDialogo(() {
                            guardando = true;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await supabase.rpc(
                              'guardar_servicio_admin',
                              params: {
                                'p_servicio_id': servicio?['id'],
                                'p_nombre': nombre,
                                'p_descripcion': descripcionController.text
                                    .trim(),
                                'p_precio': precio,
                                'p_duracion_minutos': duracion,
                              },
                            );

                            if (!mounted) return;
                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);
                            Navigator.pop(dialogContext);

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  esEdicion
                                      ? 'Servicio actualizado correctamente.'
                                      : 'Servicio registrado correctamente.',
                                ),
                                backgroundColor: verde,
                              ),
                            );

                            await cargarServicios();
                          } catch (e) {
                            debugPrint('ERROR AL GUARDAR SERVICIO: $e');

                            if (!mounted) return;

                            actualizarDialogo(() {
                              guardando = false;
                            });

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo guardar el servicio.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                  ),
                  child: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    descripcionController.dispose();
    precioController.dispose();
    duracionController.dispose();
  }

  Future<void> cambiarEstado(Map<String, dynamic> servicio) async {
    final id = servicio['id'];
    final activo = servicio['activo'] == true;

    try {
      await supabase.rpc(
        'cambiar_estado_servicio_admin',
        params: {'p_servicio_id': id, 'p_activo': !activo},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activo
                ? 'Servicio desactivado correctamente.'
                : 'Servicio activado correctamente.',
          ),
          backgroundColor: verde,
        ),
      );

      await cargarServicios();
    } catch (e) {
      debugPrint('ERROR AL CAMBIAR ESTADO: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el estado del servicio.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Gestión de servicios'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarServicios,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo servicio'),
      ),
      body: RefreshIndicator(
        onRefresh: cargarServicios,
        child: cargando
            ? const Center(child: CircularProgressIndicator(color: verde))
            : error != null
            ? ListView(
                children: [
                  const SizedBox(height: 150),
                  Center(child: Text(error!)),
                  Center(
                    child: TextButton(
                      onPressed: cargarServicios,
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : servicios.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 150),
                  Icon(Icons.medical_services_outlined, size: 60, color: verde),
                  SizedBox(height: 12),
                  Center(child: Text('No hay servicios registrados.')),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  const Text(
                    'Resumen de servicios',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Total',
                        cantidad: totalServicios,
                        icono: Icons.medical_services,
                        color: verde,
                      ),
                      tarjetaIndicador(
                        titulo: 'Activos',
                        cantidad: serviciosActivos,
                        icono: Icons.check_circle,
                        color: Colors.green,
                      ),
                      tarjetaIndicador(
                        titulo: 'Inactivos',
                        cantidad: serviciosInactivos,
                        icono: Icons.cancel,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...servicios.map((servicio) {
                    final nombre = servicio['nombre']?.toString() ?? '';
                    final descripcion =
                        servicio['descripcion']?.toString() ?? '';
                    final precio = servicio['precio'];
                    final duracion = servicio['duracion_minutos'];
                    final activo = servicio['activo'] == true;

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: verdeClaro,
                                  child: const Icon(
                                    Icons.medical_services,
                                    color: verde,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (opcion) {
                                    if (opcion == 'editar') {
                                      mostrarFormulario(servicio: servicio);
                                    } else if (opcion == 'estado') {
                                      cambiarEstado(servicio);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text('Editar'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'estado',
                                      child: Row(
                                        children: [
                                          Icon(
                                            activo
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            activo ? 'Desactivar' : 'Activar',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (descripcion.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                descripcion,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                if (precio != null)
                                  Text(
                                    'Bs ${precio.toString()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: verde,
                                    ),
                                  ),
                                if (duracion != null) Text('$duracion minutos'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  activo ? Icons.check_circle : Icons.cancel,
                                  size: 18,
                                  color: activo ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  activo ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: activo ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
