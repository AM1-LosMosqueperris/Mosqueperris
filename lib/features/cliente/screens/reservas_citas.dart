import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservasCitasScreen extends StatefulWidget {
  final String? servicioInicial;
  final VoidCallback? onOpenMenu;

  const ReservasCitasScreen({super.key, this.servicioInicial, this.onOpenMenu});

  @override
  State<ReservasCitasScreen> createState() => _ReservasCitasScreenState();
}

class _ReservasCitasScreenState extends State<ReservasCitasScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final _formKey = GlobalKey<FormState>();

  final propietarioController = TextEditingController();
  final comentarioController = TextEditingController();
  final telefonoController = TextEditingController();

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> mascotas = [];
  Map<String, dynamic>? mascotaSeleccionada;

  bool cargandoMascotas = true;
  bool cargandoCitas = true;
  bool _enviando = false;

  final List<String> servicios = [
    'Consulta veterinaria',
    'Vacunación',
    'Desparasitación',
    'Peluquería',
    'Control y seguimiento',
    'Laboratorio',
  ];

  String? servicioSeleccionado;
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;

  final List<Map<String, String>> citas = [];

  @override
  void initState() {
    super.initState();

    if (servicios.contains(widget.servicioInicial)) {
      servicioSeleccionado = widget.servicioInicial;
    }

    _cargarMascotas();
    _cargarCitas();
  }

  @override
  void didUpdateWidget(covariant ReservasCitasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.servicioInicial != widget.servicioInicial) {
      servicioSeleccionado = servicios.contains(widget.servicioInicial)
          ? widget.servicioInicial
          : null;
    }
  }

  Future<void> _actualizarTodo() async {
    await Future.wait([_cargarMascotas(), _cargarCitas()]);
  }

  Future<void> _cargarMascotas() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        mascotas = [];
        cargandoMascotas = false;
      });
      return;
    }

    try {
      final respuesta = await supabase
          .from('mascotas')
          .select('id, nombre, especie, raza')
          .eq('usuario_id', usuario.id)
          .order('nombre');

      if (!mounted) return;

      setState(() {
        mascotas = List<Map<String, dynamic>>.from(respuesta);
        cargandoMascotas = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR MASCOTAS: $e');

      if (!mounted) return;

      setState(() {
        cargandoMascotas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las mascotas.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cargarCitas() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        citas.clear();
        cargandoCitas = false;
      });
      return;
    }

    try {
      final respuesta = await supabase
          .from('reservas')
          .select()
          .eq('usuario_id', usuario.id)
          .order('fecha', ascending: false);

      if (!mounted) return;

      final nuevasCitas = <Map<String, String>>[];

      for (final reserva in respuesta) {
        final fecha = DateTime.parse(reserva['fecha'].toString());

        final horaTexto = reserva['hora']?.toString() ?? '';

        nuevasCitas.add({
          'id': reserva['id'].toString(),
          'propietario': reserva['nombre']?.toString() ?? '',
          'estado': reserva['estado']?.toString() ?? 'Pendiente',
          'mascota': reserva['mascota']?.toString() ?? 'Sin mascota',
          'servicio': reserva['servicio']?.toString() ?? 'Sin servicio',
          'fecha': '${fecha.day}/${fecha.month}/${fecha.year}',
          'hora': horaTexto.length >= 5 ? horaTexto.substring(0, 5) : horaTexto,
          'comentario': reserva['comentario']?.toString() ?? '',
          'telefono': reserva['telefono']?.toString() ?? '',
        });
      }

      setState(() {
        citas
          ..clear()
          ..addAll(nuevasCitas);
        cargandoCitas = false;
      });

      debugPrint('RESERVAS CARGADAS: ${citas.length}');
    } catch (e) {
      debugPrint('ERROR AL CARGAR RESERVAS: $e');

      if (!mounted) return;

      setState(() {
        cargandoCitas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las reservas.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmarCancelacion(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancelar reserva',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta reserva?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _cancelarCita(id);
    }
  }

  Future<void> _cancelarCita(int id) async {
    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) return;

      final respuesta = await supabase
          .from('reservas')
          .update({'estado': 'Cancelada'})
          .eq('id', id)
          .eq('usuario_id', usuario.id)
          .select('id');

      if (respuesta.isEmpty) {
        throw Exception(
          'No se encontró la reserva o no tienes permiso para cancelarla.',
        );
      }

      if (!mounted) return;

      await _cargarCitas();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada correctamente.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL CANCELAR RESERVA: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cancelar la reserva: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> seleccionarFecha() async {
    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate:
          fechaSeleccionada != null &&
              !fechaSeleccionada!.isBefore(
                DateTime(ahora.year, ahora.month, ahora.day),
              )
          ? fechaSeleccionada!
          : DateTime(ahora.year, ahora.month, ahora.day),
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 365)),
      helpText: 'Seleccionar fecha de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: verde,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF26352B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null && mounted) {
      setState(() {
        fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora de la cita',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: verde,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF26352B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (hora != null && mounted) {
      setState(() {
        horaSeleccionada = hora;
      });
    }
  }

  Future<void> solicitarCita() async {
    if (_enviando) return;

    if (!_formKey.currentState!.validate()) return;

    if (servicioSeleccionado == null ||
        mascotaSeleccionada == null ||
        fechaSeleccionada == null ||
        horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos obligatorios.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fecha = fechaSeleccionada!;
    final hora = horaSeleccionada!;

    final fechaHoraReserva = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );

    if (!fechaHoraReserva.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes seleccionar una fecha u hora pasada.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _enviando = true;
    });

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Inicia sesión'),
            content: const Text(
              'Para reservar una cita necesitas iniciar sesión '
              'o crear una cuenta en PetCare.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );

        return;
      }

      final mascota = mascotaSeleccionada!;

      await supabase.from('reservas').insert({
        'usuario_id': usuario.id,
        'mascota_id': mascota['id'],
        'nombre': propietarioController.text.trim(),
        'telefono': telefonoController.text.trim(),
        'mascota': mascota['nombre'].toString(),
        'servicio': servicioSeleccionado!,
        'comentario': comentarioController.text.trim(),
        'fecha':
            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
        'hora':
            '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00',
      });

      if (!mounted) return;

      await _cargarCitas();

      if (!mounted) return;

      propietarioController.clear();
      comentarioController.clear();
      telefonoController.clear();

      setState(() {
        mascotaSeleccionada = null;
        servicioSeleccionado = null;
        fechaSeleccionada = null;
        horaSeleccionada = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva guardada correctamente en Supabase!'),
          backgroundColor: Color(0xFF269B79),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('ERROR AL GUARDAR RESERVA: $e');
      debugPrint('DETALLE DEL ERROR: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la reserva: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    propietarioController.dispose();
    comentarioController.dispose();
    telefonoController.dispose();
    super.dispose();
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
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Row(
          children: [
            Icon(Icons.calendar_month, size: 24),
            SizedBox(width: 10),
            Text(
              'Reservas y citas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar información',
            onPressed: _actualizarTodo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: verde,
        onRefresh: _actualizarTodo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(),
                  const SizedBox(height: 25),
                  _tituloSeccion(
                    Icons.edit_calendar_outlined,
                    'Datos de la reserva',
                  ),
                  const SizedBox(height: 14),
                  _formulario(),
                  const SizedBox(height: 28),
                  _seccionCitas(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17623F), Color(0xFF248454)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: verde.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agenda una cita',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Programa la atención veterinaria de tu mascota '
                  'de forma sencilla y rápida.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cuidamos de quienes más quieres',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(IconData icono, String titulo) {
    return Row(
      children: [
        Icon(icono, color: verde, size: 23),
        const SizedBox(width: 9),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF26352B),
          ),
        ),
      ],
    );
  }

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _campoTexto(
              controller: propietarioController,
              etiqueta: 'Nombre del propietario',
              icono: Icons.person_outline,
              mensaje: 'Ingresa el nombre del propietario',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: telefonoController,
              keyboardType: TextInputType.phone,
              decoration: _decoracion(
                'Teléfono',
                Icons.phone_outlined,
                hint: 'Ej. 71234567',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu teléfono';
                }

                if (!RegExp(r'^[0-9]{8}$').hasMatch(value.trim())) {
                  return 'Ingresa un número válido de 8 dígitos';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            _selectorMascota(),
            if (cargandoMascotas)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: verde),
              )
            else if (mascotas.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFE18A16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes mascotas registradas. '
                        'Registra una antes de solicitar una cita.',
                        style: TextStyle(
                          color: Color(0xFF8A5A18),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _selectorServicio(),
            const SizedBox(height: 16),
            _selectorFecha(),
            const SizedBox(height: 16),
            _selectorHora(),
            const SizedBox(height: 16),
            TextFormField(
              controller: comentarioController,
              maxLines: 3,
              decoration: _decoracion(
                'Motivo de la consulta',
                Icons.medical_information_outlined,
                hint: 'Describe brevemente qué necesita tu mascota...',
              ).copyWith(alignLabelWithHint: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Describe el motivo de la consulta';
                }

                if (value.trim().length < 5) {
                  return 'Escribe al menos 5 caracteres';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 53,
              child: ElevatedButton.icon(
                onPressed: _enviando || cargandoMascotas || mascotas.isEmpty
                    ? null
                    : solicitarCita,
                icon: _enviando
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.event_available_outlined),
                label: Text(
                  _enviando ? 'Guardando reserva...' : 'Solicitar cita',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta, IconData icono, {String? hint}) {
    return InputDecoration(
      labelText: etiqueta,
      hintText: hint,
      prefixIcon: Icon(icono, color: verde),
      filled: true,
      fillColor: const Color(0xFFFAFCFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE1E9E2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE1E9E2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: verde, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    required String mensaje,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decoracion(etiqueta, icono),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return mensaje;
        }
        return null;
      },
    );
  }

  Widget _selectorMascota() {
    return DropdownButtonFormField<int>(
      key: ValueKey(mascotaSeleccionada?['id']),
      initialValue: mascotaSeleccionada == null
          ? null
          : (mascotaSeleccionada!['id'] as num).toInt(),
      isExpanded: true,
      decoration: _decoracion('Seleccionar mascota', Icons.pets_outlined),
      items: mascotas.map((mascota) {
        final id = (mascota['id'] as num).toInt();

        return DropdownMenuItem<int>(
          value: id,
          child: Text(
            '${mascota['nombre']} - ${mascota['especie']}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: cargandoMascotas || mascotas.isEmpty || _enviando
          ? null
          : (id) {
              if (id == null) return;

              setState(() {
                mascotaSeleccionada = mascotas.firstWhere(
                  (mascota) => (mascota['id'] as num).toInt() == id,
                );
              });
            },
      validator: (value) {
        if (value == null) {
          return 'Selecciona una mascota registrada';
        }
        return null;
      },
    );
  }

  Widget _selectorServicio() {
    return DropdownButtonFormField<String>(
      key: ValueKey(servicioSeleccionado),
      initialValue: servicioSeleccionado,
      isExpanded: true,
      decoration: _decoracion('Servicio', Icons.medical_services_outlined),
      items: servicios.map((servicio) {
        return DropdownMenuItem(
          value: servicio,
          child: Text(servicio, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _enviando
          ? null
          : (value) {
              setState(() {
                servicioSeleccionado = value;
              });
            },
      validator: (value) {
        if (value == null) {
          return 'Selecciona un servicio';
        }
        return null;
      },
    );
  }

  Widget _selectorFecha() {
    return InkWell(
      onTap: _enviando ? null : seleccionarFecha,
      borderRadius: BorderRadius.circular(13),
      child: InputDecorator(
        decoration: _decoracion(
          'Fecha de la cita',
          Icons.calendar_today_outlined,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              fechaSeleccionada == null
                  ? 'Seleccionar fecha'
                  : '${fechaSeleccionada!.day}/'
                        '${fechaSeleccionada!.month}/'
                        '${fechaSeleccionada!.year}',
              style: TextStyle(
                color: fechaSeleccionada == null
                    ? Colors.grey.shade600
                    : const Color(0xFF26352B),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: verde),
          ],
        ),
      ),
    );
  }

  Widget _selectorHora() {
    return InkWell(
      onTap: _enviando ? null : seleccionarHora,
      borderRadius: BorderRadius.circular(13),
      child: InputDecorator(
        decoration: _decoracion('Hora de la cita', Icons.access_time_outlined),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              horaSeleccionada == null
                  ? 'Seleccionar hora'
                  : horaSeleccionada!.format(context),
              style: TextStyle(
                color: horaSeleccionada == null
                    ? Colors.grey.shade600
                    : const Color(0xFF26352B),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: verde),
          ],
        ),
      ),
    );
  }

  Widget _seccionCitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.event_note_outlined, color: verde, size: 23),
                  SizedBox(width: 9),
                  Text(
                    'Mis citas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26352B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${citas.length} reservas',
                style: const TextStyle(
                  color: verde,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (cargandoCitas)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: verde),
            ),
          )
        else if (citas.isEmpty)
          _estadoVacio()
        else
          ...citas.map(_tarjetaCita),
      ],
    );
  }

  Widget _tarjetaCita(Map<String, String> cita) {
    final estado = cita['estado'] ?? 'Pendiente';
    final colorEstado = _colorEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pets, color: verde, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita['mascota'] ?? 'Sin mascota',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF26352B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cita['servicio'] ?? 'Sin servicio',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78827A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _etiquetaEstado(estado, colorEstado),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: Color(0xFFEDF1ED)),
          const SizedBox(height: 13),
          _datoCita(
            Icons.calendar_today_outlined,
            'Fecha',
            cita['fecha'] ?? '',
          ),
          const SizedBox(height: 9),
          _datoCita(Icons.access_time_outlined, 'Hora', cita['hora'] ?? ''),
          const SizedBox(height: 9),
          _datoCita(
            Icons.person_outline,
            'Propietario',
            cita['propietario'] ?? '',
          ),
          if (cita['comentario']?.isNotEmpty == true) ...[
            const SizedBox(height: 9),
            _datoCita(
              Icons.medical_information_outlined,
              'Motivo de la consulta',
              cita['comentario']!,
            ),
          ],
          if (estado.toLowerCase() == 'pendiente') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final id = int.tryParse(cita['id'] ?? '');
                  if (id != null) {
                    _confirmarCancelacion(id);
                  }
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar reserva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFD5D5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _etiquetaEstado(String estado, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEstado(estado), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            estado,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoCita(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: verde),
        const SizedBox(width: 9),
        Text(
          '$etiqueta: ',
          style: const TextStyle(
            color: Color(0xFF78827A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(color: Color(0xFF46534A), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
        return const Color(0xFF1976D2);
      case 'atendida':
        return verde;
      case 'cancelada':
        return Colors.red;
      default:
        return const Color(0xFFE18A16);
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
        return Icons.verified_outlined;
      case 'atendida':
        return Icons.check_circle_outline;
      case 'cancelada':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
    }
  }

  Widget _estadoVacio() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, size: 43, color: verde),
          SizedBox(height: 12),
          Text(
            'Todavía no tienes citas solicitadas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF526057),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Cuando reserves una cita aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
