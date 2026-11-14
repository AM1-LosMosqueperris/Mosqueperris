import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final db = Supabase.instance.client;

  List<Map<String, dynamic>> mascotas = [];
  List<Map<String, dynamic>> registros = [];

  int? mascotaSeleccionada;
  bool cargandoMascotas = true;
  bool cargandoHistorial = false;

  String filtroSeleccionado = 'Todos';

  @override
  void initState() {
    super.initState();
    cargarMascotas();
  }

  // Cargar mascotas del usuario autenticado
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

      setState(() {
        mascotas = lista;
        cargandoMascotas = false;
      });

      if (lista.isNotEmpty) {
        final primeraMascota = lista.first;
        await seleccionarMascota(int.parse(primeraMascota['id'].toString()));
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

  // Seleccionar mascota y consultar su historial
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

  // Filtrar registros
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

  // Icono según tipo de atención
  IconData obtenerIcono(String tipo) {
    final texto = tipo.toLowerCase();

    if (texto.contains('vacuna')) {
      return Icons.vaccines;
    }

    if (texto.contains('consulta') || texto.contains('cita')) {
      return Icons.calendar_month;
    }

    return Icons.medical_services;
  }

  // Color según tipo de atención
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
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Historial médico'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () async {
              if (mascotaSeleccionada != null) {
                await seleccionarMascota(mascotaSeleccionada!);
              } else {
                await cargarMascotas();
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cargandoMascotas
          ? const Center(child: CircularProgressIndicator())
          : mascotas.isEmpty
          ? mensajeSinMascotas()
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial de atención',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consulta las actividades y cuidados registrados '
                    'para tus mascotas.',
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 22),

                  selectorMascotas(),

                  const SizedBox(height: 20),

                  filtro(),

                  const SizedBox(height: 20),

                  if (cargandoHistorial)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
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

  // Selector de mascotas
  Widget selectorMascotas() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<int>(
        initialValue: mascotaSeleccionada,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Seleccionar mascota',
          prefixIcon: Icon(Icons.pets, color: verde),
          border: InputBorder.none,
        ),
        items: mascotas.map((mascota) {
          final id = int.parse(mascota['id'].toString());

          return DropdownMenuItem<int>(
            value: id,
            child: Text(mascota['nombre']?.toString() ?? 'Sin nombre'),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            seleccionarMascota(id);
          }
        },
      ),
    );
  }

  // Filtro del historial
  Widget filtro() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: filtroSeleccionado,
        decoration: const InputDecoration(
          labelText: 'Filtrar historial',
          border: InputBorder.none,
        ),
        items: const [
          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
          DropdownMenuItem(value: 'Citas', child: Text('Citas')),
          DropdownMenuItem(value: 'Vacunas', child: Text('Vacunas')),
          DropdownMenuItem(value: 'Otros', child: Text('Otros cuidados')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              filtroSeleccionado = value;
            });
          }
        },
      ),
    );
  }

  // Tarjeta de registro médico
  Widget elementoHistorial(Map<String, dynamic> registro) {
    final tipo = registro['tipo']?.toString() ?? 'Atención médica';
    final fecha = registro['fecha']?.toString() ?? '';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: obtenerColor(tipo).withValues(alpha: 0.12),
                  child: Icon(obtenerIcono(tipo), color: obtenerColor(tipo)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tipo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Fecha: $fecha',
              style: const TextStyle(color: Colors.black54),
            ),
            const Divider(height: 22),

            if (registro['descripcion'] != null)
              detalle('Descripción', registro['descripcion']),

            if (registro['diagnostico'] != null)
              detalle('Diagnóstico', registro['diagnostico']),

            if (registro['tratamiento'] != null)
              detalle('Tratamiento', registro['tratamiento']),

            if (registro['vacuna'] != null)
              detalle('Vacuna', registro['vacuna']),

            if (registro['observaciones'] != null)
              detalle('Observaciones', registro['observaciones']),

            if (registro['veterinario'] != null)
              detalle('Veterinario', registro['veterinario']),
          ],
        ),
      ),
    );
  }

  // Mostrar detalles
  Widget detalle(String titulo, dynamic valor) {
    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.4),
          children: [
            TextSpan(
              text: '$titulo: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: texto),
          ],
        ),
      ),
    );
  }

  // Cuando no existen mascotas
  Widget mensajeSinMascotas() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 60, color: verde),
            SizedBox(height: 15),
            Text(
              'Todavía no tienes mascotas',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Registra una mascota para consultar su historial médico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Cuando no existen registros médicos
  Widget mensajeVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: verdeClaro,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(Icons.history, size: 45, color: verde),
          SizedBox(height: 10),
          Text(
            'Todavía no hay registros',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: verde,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Cuando se registren consultas, vacunas o tratamientos, '
            'podrás consultar aquí su historial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
