import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/utils/fechas.dart';

class CitasVeterinarioScreen extends StatefulWidget {
  const CitasVeterinarioScreen({super.key});

  @override
  State<CitasVeterinarioScreen> createState() => _CitasVeterinarioScreenState();
}

class _CitasVeterinarioScreenState extends State<CitasVeterinarioScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final supabase = Supabase.instance.client;
  RealtimeChannel? canalReservas;

  List<Map<String, dynamic>> reservas = [];

  bool cargando = true;
  String? error;
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
    escucharReservas();
  }

  void escucharReservas() {
    canalReservas = supabase
        .channel('reservas-veterinario')
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

  Future<void> cargarReservas({bool mostrarCarga = true}) async {
    if (!mounted) return;

    if (mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final respuesta = await supabase
          .from('reservas')
          .select()
          .order('fecha', ascending: false);

      if (!mounted) return;

      setState(() {
        reservas = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR RESERVAS: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las citas.';
        cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get reservasFiltradas {
    if (filtroEstado == 'Todas') {
      return reservas;
    }

    return reservas.where((reserva) {
      return (reserva['estado']?.toString() ?? 'Pendiente') == filtroEstado;
    }).toList();
  }

  Future<void> cambiarEstado(
    Map<String, dynamic> reserva,
    String nuevoEstado,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nuevoEstado == 'Confirmada' ? 'Confirmar cita' : 'Cancelar cita',
        ),
        content: Text(
          nuevoEstado == 'Confirmada'
              ? '¿Deseas confirmar esta cita?'
              : '¿Estás seguro de que deseas cancelar esta cita?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'Cancelada' ? Colors.red : verde,
              foregroundColor: Colors.white,
            ),
            child: Text(
              nuevoEstado == 'Confirmada' ? 'Confirmar' : 'Cancelar cita',
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      final respuesta = await supabase
          .from('reservas')
          .update({'estado': nuevoEstado})
          .eq('id', reserva['id'])
          .eq('estado', 'Pendiente')
          .select('id');

      if (respuesta.isEmpty) {
        if (!mounted) return;

        await cargarReservas(mostrarCarga: false);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Esta cita ya no esta pendiente. Se actualizo la lista.',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      if (!mounted) return;

      await cargarReservas();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'Confirmada'
                ? 'Cita confirmada correctamente.'
                : 'Cita cancelada correctamente.',
          ),
          backgroundColor: verde,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL ACTUALIZAR CITA: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la cita: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> atenderCita(Map<String, dynamic> reserva) async {
    final mascotaId = reserva['mascota_id'];
    final usuarioId = reserva['usuario_id'];
    final reservaId = reserva['id'];

    if (mascotaId == null || usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta reserva no tiene una mascota vinculada. '
            'No se puede registrar la atención médica.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tipoController = TextEditingController(
      text: reserva['servicio']?.toString() ?? 'Consulta',
    );
    final descripcionController = TextEditingController();
    final diagnosticoController = TextEditingController();
    final tratamientoController = TextEditingController();
    final vacunaController = TextEditingController();
    final observacionesController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool guardando = false;

    try {
      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, actualizarDialogo) {
              return AlertDialog(
                title: const Text(
                  'Registrar atención médica',
                  style: TextStyle(color: verde, fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mascota: ${reserva['mascota'] ?? 'Sin nombre'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),

                          _campoMedico(
                            controller: tipoController,
                            label: 'Tipo de atención',
                            icono: Icons.medical_services,
                            obligatorio: true,
                          ),

                          _campoMedico(
                            controller: descripcionController,
                            label: 'Descripción de la atención',
                            icono: Icons.description,
                            obligatorio: true,
                            maxLines: 3,
                          ),

                          _campoMedico(
                            controller: diagnosticoController,
                            label: 'Diagnóstico',
                            icono: Icons.health_and_safety,
                            maxLines: 2,
                          ),

                          _campoMedico(
                            controller: tratamientoController,
                            label: 'Tratamiento',
                            icono: Icons.medication,
                            maxLines: 2,
                          ),

                          _campoMedico(
                            controller: vacunaController,
                            label: 'Vacuna',
                            icono: Icons.vaccines,
                          ),

                          _campoMedico(
                            controller: observacionesController,
                            label: 'Observaciones',
                            icono: Icons.notes,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: guardando
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Volver'),
                  ),
                  ElevatedButton.icon(
                    onPressed: guardando
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            actualizarDialogo(() {
                              guardando = true;
                            });

                            try {
                              final rpcDisponible =
                                  await _registrarAtencionConRpc(
                                    reservaId: reservaId,
                                    tipo: tipoController.text.trim(),
                                    descripcion: descripcionController.text
                                        .trim(),
                                    diagnostico: diagnosticoController.text
                                        .trim(),
                                    tratamiento: tratamientoController.text
                                        .trim(),
                                    vacuna: vacunaController.text.trim(),
                                    observaciones: observacionesController.text
                                        .trim(),
                                  );

                              if (!rpcDisponible) {
                                // La RPC no está desplegada en este entorno:
                                // se recurre al flujo anterior (INSERT + UPDATE).
                                await _registrarAtencionFlujoAnterior(
                                  reservaId: reservaId,
                                  mascotaId: mascotaId,
                                  usuarioId: usuarioId,
                                  tipo: tipoController.text.trim(),
                                  descripcion: descripcionController.text
                                      .trim(),
                                  diagnostico: diagnosticoController.text
                                      .trim(),
                                  tratamiento: tratamientoController.text
                                      .trim(),
                                  vacuna: vacunaController.text.trim(),
                                  observaciones: observacionesController.text
                                      .trim(),
                                );
                              }

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext, true);
                            } on PostgrestException catch (e) {
                              debugPrint('ERROR AL REGISTRAR ATENCIÓN: $e');

                              actualizarDialogo(() {
                                guardando = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(_mensajeErrorAtencion(e)),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } catch (e) {
                              debugPrint('ERROR AL REGISTRAR ATENCIÓN: $e');

                              actualizarDialogo(() {
                                guardando = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo registrar la atención. '
                                    'Inténtalo de nuevo.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      guardando ? 'Guardando...' : 'Guardar atención',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (resultado == true && mounted) {
        await cargarReservas();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atención registrada y cita marcada como atendida.'),
            backgroundColor: verde,
          ),
        );
      }
    } finally {
      tipoController.dispose();
      descripcionController.dispose();
      diagnosticoController.dispose();
      tratamientoController.dispose();
      vacunaController.dispose();
      observacionesController.dispose();
    }
  }

  /// Registra la atención médica mediante la RPC transaccional `atender_cita`,
  /// que escribe el historial médico y cierra la cita en una sola transacción
  /// (evita que quede una atención registrada con la cita sin cerrar).
  ///
  /// Devuelve `true` si la RPC estaba disponible y ejecutó el registro.
  /// Devuelve `false` si la RPC no existe en este entorno, para poder
  /// recurrir al flujo anterior sin perder la funcionalidad.
  Future<bool> _registrarAtencionConRpc({
    required dynamic reservaId,
    required String tipo,
    required String descripcion,
    required String diagnostico,
    required String tratamiento,
    required String vacuna,
    required String observaciones,
  }) async {
    try {
      await supabase.rpc(
        'atender_cita',
        params: {
          'p_reserva_id': int.parse(reservaId.toString()),
          'p_tipo': tipo,
          'p_descripcion': descripcion,
          'p_diagnostico': diagnostico,
          'p_tratamiento': tratamiento,
          'p_vacuna': vacuna,
          'p_observaciones': observaciones,
        },
      );

      return true;
    } on PostgrestException catch (e) {
      final codigo = e.code ?? '';
      final mensaje = e.message.toLowerCase();

      final rpcAusente =
          codigo == '42883' ||
          codigo == '42P01' ||
          codigo == 'PGRST202' ||
          (mensaje.contains('atender_cita') &&
              (mensaje.contains('no existe') ||
                  mensaje.contains('not found') ||
                  mensaje.contains('could not find')));

      if (rpcAusente) {
        debugPrint(
          'La RPC atender_cita no está disponible en este entorno. '
          'Se usará el flujo de registro anterior.',
        );

        return false;
      }

      rethrow;
    }
  }

  /// Flujo de registro anterior a la RPC transaccional.
  ///
  /// Se conserva como respaldo para entornos donde `atender_cita` todavía no
  /// está desplegada. Mantiene exactamente el comportamiento original:
  /// deduplica, inserta el historial y después marca la reserva como atendida.
  Future<void> _registrarAtencionFlujoAnterior({
    required dynamic reservaId,
    required dynamic mascotaId,
    required dynamic usuarioId,
    required String tipo,
    required String descripcion,
    required String diagnostico,
    required String tratamiento,
    required String vacuna,
    required String observaciones,
  }) async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('Debes iniciar sesión nuevamente.');
    }

    final perfil = await supabase
        .from('perfiles')
        .select('nombre')
        .eq('id', usuario.id)
        .maybeSingle();

    final nombreVeterinario = perfil?['nombre']?.toString() ?? 'Veterinario';

    final fechaAtencion = DateTime.now().toIso8601String().substring(0, 10);

    // Comprobar si ya existe una atención registrada para esta reserva.
    final historialExistente = await supabase
        .from('historial_medico')
        .select('id')
        .eq('mascota_id', mascotaId)
        .eq('usuario_id', usuarioId)
        .eq('veterinario_id', usuario.id)
        .eq('descripcion', descripcion)
        .eq('fecha', fechaAtencion)
        .limit(1);

    if (historialExistente.isEmpty) {
      await supabase.from('historial_medico').insert({
        'usuario_id': usuarioId,
        'mascota_id': mascotaId,
        'veterinario_id': usuario.id,
        'fecha': fechaAtencion,
        'tipo': tipo,
        'descripcion': descripcion,
        'diagnostico': diagnostico,
        'tratamiento': tratamiento,
        'vacuna': vacuna,
        'observaciones': observaciones,
        'veterinario': nombreVeterinario,
      });
    }

    // Actualizar la reserva solamente después de guardar o comprobar el historial.
    await supabase
        .from('reservas')
        .update({'estado': 'Atendida'})
        .eq('id', reservaId)
        .eq('estado', 'Confirmada');
  }

  /// Traduce el error de la RPC a un mensaje comprensible para el usuario.
  String _mensajeErrorAtencion(PostgrestException e) {
    // P0001: error de negocio lanzado por la RPC con un mensaje en español.
    if (e.code == 'P0001') {
      var mensaje = e.message.trim();

      if (mensaje.toUpperCase().startsWith('ERROR:')) {
        mensaje = mensaje.substring(6).trim();
      }

      if (mensaje.isNotEmpty) return mensaje;
    }

    return 'No se pudo registrar la atención. Inténtalo de nuevo.';
  }

  Widget _campoMedico({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    bool obligatorio = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icono, color: verde),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: obligatorio
            ? (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Este campo es obligatorio.';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'Confirmada':
        return Colors.green;
      case 'Atendida':
        return Colors.blue;
      case 'Cancelada':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String formatearFecha(dynamic valor) {
    if (valor == null) return 'Sin fecha';

    final texto = Fechas.formatearFecha(valor);

    return texto.isEmpty ? valor.toString() : texto;
  }

  @override
  void dispose() {
    if (canalReservas != null) {
      supabase.removeChannel(canalReservas!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: null,
      body: RefreshIndicator(
        onRefresh: cargarReservas,
        child: cargando
            ? const Center(child: CircularProgressIndicator(color: verde))
            : error != null
            ? ListView(
                children: [
                  const SizedBox(height: 150),
                  Center(child: Text(error!)),
                  Center(
                    child: TextButton(
                      onPressed: cargarReservas,
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: verdeClaro,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Administración de reservas',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${reservas.length} citas registradas',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Filtrar por estado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: filtroEstado,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.filter_list, color: verde),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: estados.map((estado) {
                      return DropdownMenuItem(
                        value: estado,
                        child: Text(estado),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      if (valor == null) return;

                      setState(() {
                        filtroEstado = valor;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Citas (${reservasFiltradas.length})',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (reservasFiltradas.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(25),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No hay citas para mostrar.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  ...reservasFiltradas.map((reserva) {
                    final estado = reserva['estado']?.toString() ?? 'Pendiente';

                    final mascota =
                        reserva['mascota']?.toString() ?? 'Sin mascota';

                    final propietario =
                        reserva['nombre']?.toString() ?? 'Sin nombre';

                    final servicio =
                        reserva['servicio']?.toString() ?? 'Sin servicio';

                    final telefono =
                        reserva['telefono']?.toString() ?? 'Sin teléfono';

                    final hora = Fechas.formatearHora(reserva['hora']);

                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: verdeClaro,
                                  child: Icon(Icons.pets, color: verde),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mascota,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorEstado(estado)
                                        .withValues(alpha: 0.12),
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

                            const Divider(height: 25),

                            _dato(Icons.person, 'Propietario', propietario),
                            _dato(Icons.phone, 'Teléfono', telefono),
                            _dato(Icons.medical_services, 'Servicio', servicio),
                            _dato(
                              Icons.calendar_today,
                              'Fecha',
                              formatearFecha(reserva['fecha']),
                            ),
                            _dato(Icons.access_time, 'Hora', hora),
                            if ((reserva['comentario']?.toString() ?? '')
                                .trim()
                                .isNotEmpty)
                              _dato(
                                Icons.comment,
                                'Motivo de consulta',
                                reserva['comentario'].toString(),
                              ),

                            if (estado == 'Pendiente') ...[
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          cambiarEstado(reserva, 'Cancelada'),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Cancelar'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          cambiarEstado(reserva, 'Confirmada'),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Confirmar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: verde,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (estado == 'Confirmada') ...[
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => atenderCita(reserva),
                                  icon: const Icon(Icons.assignment_turned_in),
                                  label: const Text('Atender cita'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: verde,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _dato(IconData icono, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: verde),
          const SizedBox(width: 10),
          Text(
            '$titulo: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}
