import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultasVeterinarioScreen extends StatefulWidget {
  const ConsultasVeterinarioScreen({super.key});

  @override
  State<ConsultasVeterinarioScreen> createState() =>
      _ConsultasVeterinarioScreenState();
}

class _ConsultasVeterinarioScreenState
    extends State<ConsultasVeterinarioScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final supabase = Supabase.instance.client;

  RealtimeChannel? _canalConsultas;

  List<Map<String, dynamic>> consultas = [];

  bool cargando = true;
  bool procesando = false;
  String? error;

  String get usuarioId => supabase.auth.currentUser?.id ?? '';

  List<Map<String, dynamic>> get consultasDisponibles {
    return consultas.where((consulta) {
      return consulta['estado'] == 'Admitida' && consulta['asignado_a'] == null;
    }).toList();
  }

  List<Map<String, dynamic>> get consultasEnAtencion {
    return consultas.where((consulta) {
      return consulta['estado'] == 'En atención' &&
          consulta['asignado_a'] == usuarioId;
    }).toList();
  }

  List<Map<String, dynamic>> get consultasAtendidas {
    return consultas.where((consulta) {
      return consulta['estado'] == 'Atendida' &&
          consulta['asignado_a'] == usuarioId;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarConsultas();
    escucharConsultas();
  }

  @override
  void dispose() {
    if (_canalConsultas != null) {
      supabase.removeChannel(_canalConsultas!);
    }

    super.dispose();
  }

  void escucharConsultas() {
    _canalConsultas = supabase
        .channel('consultas-veterinario-$usuarioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'consultas',
          callback: (payload) {
            cargarConsultas(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  Future<void> cargarConsultas({bool mostrarCarga = true}) async {
    if (!mounted) return;

    if (mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final datos = await supabase
          .from('consultas')
          .select(
            'id, nombre, telefono, mensaje, created_at, estado, tipo, '
            'asignado_a, respuesta, respondida_en, mascota_id',
          )
          .eq('tipo', 'Veterinaria')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        consultas = List<Map<String, dynamic>>.from(datos);
        cargando = false;
        error = null;
      });
    } catch (e) {
      debugPrint('Error al cargar consultas veterinarias: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las consultas.';
        cargando = false;
      });
    }
  }

  Future<void> tomarConsulta(Map<String, dynamic> consulta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tomar consulta'),
        content: const Text(
          '¿Deseas hacerte responsable de atender esta consulta? '
          'Una vez tomada, los demás veterinarios ya no podrán responderla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tomar consulta'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      procesando = true;
    });

    try {
      await supabase.rpc(
        'tomar_consulta',
        params: {'p_consulta_id': consulta['id']},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has tomado la consulta correctamente.'),
          backgroundColor: verde,
        ),
      );

      await cargarConsultas(mostrarCarga: false);
    } catch (e) {
      debugPrint('Error al tomar consulta: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo tomar la consulta. Es posible que otro veterinario ya la haya tomado.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      await cargarConsultas(mostrarCarga: false);
    } finally {
      if (mounted) {
        setState(() {
          procesando = false;
        });
      }
    }
  }

  Future<void> responderConsulta(Map<String, dynamic> consulta) async {
    final controller = TextEditingController();

    final respuesta = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe una respuesta para el cliente. '
              'La consulta quedará marcada como atendida.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 7,
              maxLength: 1500,
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: verde, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final texto = controller.text.trim();

              if (texto.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La respuesta debe tener al menos 10 caracteres.',
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(context, texto);
            },
            child: const Text('Enviar respuesta'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (respuesta == null || !mounted) return;

    setState(() {
      procesando = true;
    });

    try {
      await supabase.rpc(
        'responder_consulta',
        params: {'p_consulta_id': consulta['id'], 'p_respuesta': respuesta},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respuesta enviada correctamente.'),
          backgroundColor: verde,
        ),
      );

      await cargarConsultas(mostrarCarga: false);
    } catch (e) {
      debugPrint('Error al responder consulta: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo enviar la respuesta. Verifica que la consulta siga asignada a ti.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );

      await cargarConsultas(mostrarCarga: false);
    } finally {
      if (mounted) {
        setState(() {
          procesando = false;
        });
      }
    }
  }

  String formatoFecha(dynamic fecha) {
    if (fecha == null) return 'Fecha no disponible';

    try {
      final date = DateTime.parse(fecha.toString()).toLocal();

      final dia = date.day.toString().padLeft(2, '0');
      final mes = date.month.toString().padLeft(2, '0');
      final anio = date.year.toString();

      final hora = date.hour.toString().padLeft(2, '0');
      final minuto = date.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$anio - $hora:$minuto';
    } catch (_) {
      return 'Fecha no disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: null,
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.redAccent,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: cargarConsultas,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: verde,
              onRefresh: cargarConsultas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  encabezado(),

                  const SizedBox(height: 18),

                  resumen(),

                  const SizedBox(height: 25),

                  seccion(
                    titulo: 'Consultas disponibles',
                    subtitulo:
                        'Consultas admitidas que puedes tomar para atender.',
                    icono: Icons.inbox_rounded,
                    color: Colors.blue,
                    lista: consultasDisponibles,
                    vacio: 'No hay consultas disponibles por el momento.',
                    tipo: 'disponible',
                  ),

                  const SizedBox(height: 25),

                  seccion(
                    titulo: 'En atención',
                    subtitulo: 'Consultas que están bajo tu responsabilidad.',
                    icono: Icons.medical_services_rounded,
                    color: Colors.orange,
                    lista: consultasEnAtencion,
                    vacio: 'No tienes consultas pendientes de respuesta.',
                    tipo: 'atencion',
                  ),

                  const SizedBox(height: 25),

                  seccion(
                    titulo: 'Consultas atendidas',
                    subtitulo: 'Historial de tus consultas respondidas.',
                    icono: Icons.check_circle_rounded,
                    color: verde,
                    lista: consultasAtendidas,
                    vacio: 'Todavía no has atendido consultas.',
                    tipo: 'atendida',
                  ),
                ],
              ),
            ),
    );
  }

  Widget encabezado() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [verde, Color(0xFF258456)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATENCIÓN VETERINARIA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Gestión de consultas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Revisa las solicitudes y brinda atención a los clientes.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(Icons.medical_services_rounded, color: Colors.white, size: 42),
        ],
      ),
    );
  }

  Widget resumen() {
    return Row(
      children: [
        Expanded(
          child: indicador(
            'Disponibles',
            consultasDisponibles.length,
            Icons.inbox_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: indicador(
            'En atención',
            consultasEnAtencion.length,
            Icons.medical_services_rounded,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: indicador(
            'Atendidas',
            consultasAtendidas.length,
            Icons.check_circle_rounded,
            verde,
          ),
        ),
      ],
    );
  }

  Widget indicador(String titulo, int cantidad, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 7),
          Text(
            '$cantidad',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget seccion({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required List<Map<String, dynamic>> lista,
    required String vacio,
    required String tipo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: color, size: 23),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  color: Color(0xFF26372C),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${lista.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitulo,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 13),
        if (lista.isEmpty)
          mensajeVacio(vacio)
        else
          ...lista.map((consulta) => tarjetaConsulta(consulta, tipo)),
      ],
    );
  }

  Widget tarjetaConsulta(Map<String, dynamic> consulta, String tipo) {
    final nombre = consulta['nombre']?.toString() ?? 'Cliente';
    final telefono = consulta['telefono']?.toString() ?? '';
    final mensaje = consulta['mensaje']?.toString() ?? '';
    final respuesta = consulta['respuesta']?.toString();

    final estado = consulta['estado']?.toString() ?? '';
    final fecha = formatoFecha(consulta['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    color: Color(0xFF26372C),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              estadoEtiqueta(estado),
            ],
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: Colors.black45,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fecha,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ),
            ],
          ),

          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: Colors.black45,
                ),
                const SizedBox(width: 6),
                Text(
                  telefono,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          const Text(
            'Consulta del cliente',
            style: TextStyle(
              color: verde,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            mensaje,
            style: const TextStyle(
              color: Color(0xFF39463D),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          if (consulta['mascota_id'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pets_rounded, size: 15, color: verde),
                const SizedBox(width: 5),
                Text(
                  'Mascota asociada: #${consulta['mascota_id']}',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ],

          if (tipo == 'atendida' && respuesta != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu respuesta',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    respuesta,
                    style: const TextStyle(
                      color: Color(0xFF39463D),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (tipo != 'atendida') ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: procesando
                    ? null
                    : () {
                        if (tipo == 'disponible') {
                          tomarConsulta(consulta);
                        } else {
                          responderConsulta(consulta);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: Icon(
                  tipo == 'disponible'
                      ? Icons.assignment_turned_in_rounded
                      : Icons.send_rounded,
                  size: 18,
                ),
                label: Text(
                  tipo == 'disponible'
                      ? 'Tomar consulta'
                      : 'Responder consulta',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget estadoEtiqueta(String estado) {
    Color color;
    Color fondoEtiqueta;

    switch (estado) {
      case 'Admitida':
        color = Colors.blue.shade700;
        fondoEtiqueta = Colors.blue.shade50;
        break;
      case 'En atención':
        color = Colors.orange.shade800;
        fondoEtiqueta = Colors.orange.shade50;
        break;
      case 'Atendida':
        color = verde;
        fondoEtiqueta = verdeClaro;
        break;
      default:
        color = Colors.grey.shade700;
        fondoEtiqueta = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fondoEtiqueta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget mensajeVacio(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.black38, size: 30),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
