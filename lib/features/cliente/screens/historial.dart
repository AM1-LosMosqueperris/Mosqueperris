import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistorialScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const HistorialScreen({super.key, this.onOpenMenu});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final db = Supabase.instance.client;
  RealtimeChannel? _canalHistorial;

  List<Map<String, dynamic>> mascotas = [];
  List<Map<String, dynamic>> registros = [];

  int? mascotaSeleccionada;
  bool cargandoMascotas = true;
  bool cargandoHistorial = false;

  String filtroSeleccionado = 'Todos';

  void _escucharCambios() {
    final usuario = db.auth.currentUser;

    if (usuario == null) return;

    _canalHistorial = db
        .channel('historial-cliente-${usuario.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mascotas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            cargarMascotas();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'historial_medico',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            final id = mascotaSeleccionada;

            if (id != null) {
              seleccionarMascota(id);
            }
          },
        )
        .subscribe();
  }

  @override
  void initState() {
    super.initState();
    _escucharCambios();
    cargarMascotas();
  }

  @override
  void dispose() {
    if (_canalHistorial != null) {
      db.removeChannel(_canalHistorial!);
    }

    super.dispose();
  }

  Future<void> cargarMascotas() async {
    try {
      final usuario = db.auth.currentUser;

      if (usuario == null) {
        throw Exception('Usuario no autenticado');
      }

      final datos = await db
          .from('mascotas')
          .select('id, nombre, especie, raza')
          .eq('usuario_id', usuario.id)
          .order('nombre');

      if (!mounted) return;

      final lista = List<Map<String, dynamic>>.from(datos);
      final idAnterior = mascotaSeleccionada;

      setState(() {
        mascotas = lista;
        cargandoMascotas = false;
      });

      if (lista.isNotEmpty) {
        final existeAnterior = lista.any(
          (mascota) => int.parse(mascota['id'].toString()) == idAnterior,
        );

        final id = existeAnterior
            ? idAnterior!
            : int.parse(lista.first['id'].toString());

        await seleccionarMascota(id);
      } else {
        setState(() {
          mascotaSeleccionada = null;
          registros = [];
          cargandoHistorial = false;
        });
      }
    } catch (e) {
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

  Future<void> seleccionarMascota(int id) async {
    final usuario = db.auth.currentUser;

    if (usuario == null) return;

    setState(() {
      mascotaSeleccionada = id;
      registros = [];
      cargandoHistorial = true;
      filtroSeleccionado = 'Todos';
    });

    try {
      final datos = await db
          .from('historial_medico')
          .select()
          .eq('mascota_id', id)
          .eq('usuario_id', usuario.id)
          .order('fecha', ascending: false);

      if (!mounted) return;

      setState(() {
        registros = List<Map<String, dynamic>>.from(datos);
        cargandoHistorial = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargandoHistorial = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el historial médico.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> actualizar() async {
    if (mascotaSeleccionada != null) {
      await seleccionarMascota(mascotaSeleccionada!);
    } else {
      await cargarMascotas();
    }
  }

  List<Map<String, dynamic>> get registrosFiltrados {
    if (filtroSeleccionado == 'Todos') {
      return registros;
    }

    return registros.where((registro) {
      final tipo = (registro['tipo'] ?? '').toString().toLowerCase();

      if (filtroSeleccionado == 'Citas') {
        return tipo.contains('consulta') || tipo.contains('cita');
      }

      if (filtroSeleccionado == 'Vacunas') {
        return tipo.contains('vacuna') ||
            (registro['vacuna'] != null &&
                registro['vacuna'].toString().trim().isNotEmpty);
      }

      if (filtroSeleccionado == 'Otros') {
        return !tipo.contains('consulta') &&
            !tipo.contains('cita') &&
            !tipo.contains('vacuna');
      }

      return true;
    }).toList();
  }

  IconData obtenerIcono(String tipo) {
    final texto = tipo.toLowerCase();

    if (texto.contains('vacuna')) {
      return Icons.vaccines_rounded;
    }

    if (texto.contains('consulta') || texto.contains('cita')) {
      return Icons.calendar_month_rounded;
    }

    return Icons.medical_services_rounded;
  }

  Color obtenerColor(String tipo) {
    final texto = tipo.toLowerCase();

    if (texto.contains('vacuna')) {
      return verde;
    }

    if (texto.contains('consulta') || texto.contains('cita')) {
      return Colors.blue;
    }

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final lista = registrosFiltrados;

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: verde,
        foregroundColor: Colors.white,
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Text(
          'Historial médico',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: actualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: cargandoMascotas
          ? const Center(child: CircularProgressIndicator(color: verde))
          : mascotas.isEmpty
          ? RefreshIndicator(
              color: verde,
              onRefresh: cargarMascotas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: mensajeSinMascotas(),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: verde,
              onRefresh: actualizar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                children: [
                  encabezado(),

                  const SizedBox(height: 22),

                  selectorMascotas(),

                  const SizedBox(height: 22),

                  resumenHistorial(),

                  const SizedBox(height: 24),

                  tituloSeccion(
                    'Registros médicos',
                    'Consulta las atenciones de tu mascota',
                  ),

                  const SizedBox(height: 14),

                  filtro(),

                  const SizedBox(height: 18),

                  if (cargandoHistorial)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Center(
                        child: CircularProgressIndicator(color: verde),
                      ),
                    )
                  else if (lista.isEmpty)
                    mensajeVacio()
                  else
                    ...lista.map(elementoHistorial),
                ],
              ),
            ),
    );
  }

  Widget encabezado() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [verde, Color(0xFF258456)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: verde.withValues(alpha: 0.18),
            blurRadius: 14,
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
                  'Cuidado y bienestar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Historial de atención',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toda la información médica de tus mascotas en un solo lugar.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_information_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget selectorMascotas() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EEE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pets_rounded, color: verde, size: 20),
              SizedBox(width: 8),
              Text(
                'Selecciona tu mascota',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: verde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: mascotaSeleccionada,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: fondo,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('Seleccionar mascota'),
            items: mascotas.map((mascota) {
              final id = int.parse(mascota['id'].toString());
              final nombre = mascota['nombre']?.toString() ?? 'Sin nombre';
              final especie = mascota['especie']?.toString() ?? '';

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '$nombre${especie.isNotEmpty ? ' • $especie' : ''}',
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id != null) {
                seleccionarMascota(id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget resumenHistorial() {
    final mascota = mascotas.firstWhere(
      (elemento) => int.parse(elemento['id'].toString()) == mascotaSeleccionada,
      orElse: () => {},
    );

    final nombre = mascota['nombre']?.toString() ?? 'Tu mascota';
    final especie = mascota['especie']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: verdeClaro,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets_rounded, color: verde, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                if (especie.isNotEmpty)
                  Text(
                    especie,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${registros.length}',
                style: const TextStyle(
                  color: verde,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Registros',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget tituloSeccion(String titulo, String subtitulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFF24352B),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitulo,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }

  Widget filtro() {
    const opciones = ['Todos', 'Citas', 'Vacunas', 'Otros'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opciones.map((opcion) {
          final seleccionado = filtroSeleccionado == opcion;

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: ChoiceChip(
              label: Text(opcion == 'Otros' ? 'Otros cuidados' : opcion),
              selected: seleccionado,
              showCheckmark: false,
              selectedColor: verde,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: seleccionado ? verde : const Color(0xFFE1E9E2),
              ),
              labelStyle: TextStyle(
                color: seleccionado ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (_) {
                setState(() {
                  filtroSeleccionado = opcion;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget elementoHistorial(Map<String, dynamic> registro) {
    final tipo = registro['tipo']?.toString() ?? 'Atención médica';
    final fecha = registro['fecha']?.toString() ?? '';
    final color = obtenerColor(tipo);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(obtenerIcono(tipo), color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tipo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26372C),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: verde,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    fecha.isEmpty ? 'Fecha no disponible' : fecha,
                    style: const TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: Color(0xFFEDF1ED)),
            ),

            detalle('Descripción', registro['descripcion']),
            detalle('Diagnóstico', registro['diagnostico']),
            detalle('Tratamiento', registro['tratamiento']),
            detalle('Vacuna', registro['vacuna']),
            detalle('Observaciones', registro['observaciones']),
            detalle('Veterinario', registro['veterinario']),
          ],
        ),
      ),
    );
  }

  Widget detalle(String titulo, dynamic valor) {
    final texto = valor?.toString().trim() ?? '';

    if (texto.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, right: 9),
            decoration: const BoxDecoration(
              color: verde,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF4D5950),
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: '$titulo: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26372C),
                    ),
                  ),
                  TextSpan(text: texto),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget mensajeSinMascotas() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: verdeClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets_rounded, size: 48, color: verde),
            ),
            const SizedBox(height: 18),
            const Text(
              'Todavía no tienes mascotas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Registra una mascota para consultar su historial médico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget mensajeVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEE9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: verdeClaro,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 36, color: verde),
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay registros para mostrar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: verde,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            filtroSeleccionado == 'Todos'
                ? 'Cuando se registren consultas, vacunas o tratamientos, aparecerán aquí.'
                : 'No hay registros dentro de la categoría "$filtroSeleccionado". Prueba con otro filtro.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
