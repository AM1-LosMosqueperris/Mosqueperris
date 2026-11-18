import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GestionConsultasAdminScreen extends StatefulWidget {
  const GestionConsultasAdminScreen({super.key});

  @override
  State<GestionConsultasAdminScreen> createState() =>
      _GestionConsultasAdminScreenState();
}

class _GestionConsultasAdminScreenState
    extends State<GestionConsultasAdminScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color fondo = Color(0xFFF7FAF6);

  final supabase = Supabase.instance.client;
  final TextEditingController busquedaController = TextEditingController();

  List<Map<String, dynamic>> consultas = [];

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

  RealtimeChannel? _canalConsultas;
  final Set<int> consultasActualizando = {};

  int get totalConsultas => consultas.length;

  int get consultasPendientes =>
      consultas.where((c) => c['estado'] == 'Pendiente').length;

  int get consultasEnProceso => consultas
      .where((c) => ['Admitida', 'En atención'].contains(c['estado']))
      .length;

  int get consultasAtendidas =>
      consultas.where((c) => c['estado'] == 'Atendida').length;

  List<Map<String, dynamic>> get consultasFiltradas {
    final busqueda = textoBusqueda.toLowerCase().trim();

    if (busqueda.isEmpty) return consultas;

    return consultas.where((consulta) {
      final nombre = (consulta['nombre'] ?? '').toString().toLowerCase();
      final telefono = (consulta['telefono'] ?? '').toString().toLowerCase();
      final mensaje = (consulta['mensaje'] ?? '').toString().toLowerCase();

      return nombre.contains(busqueda) ||
          telefono.contains(busqueda) ||
          mensaje.contains(busqueda);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarConsultas();
    escucharConsultas();
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
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        consultas = List<Map<String, dynamic>>.from(datos);
        cargando = false;
        error = null;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR CONSULTAS: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las consultas.';
      });
    }
  }

  /// Admite una consulta veterinaria para que todos los veterinarios
  /// puedan verla y uno de ellos pueda tomarla.
  Future<void> admitirConsulta(Map<String, dynamic> consulta) async {
    final id = int.tryParse(consulta['id'].toString());

    if (id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Admitir consulta veterinaria',
            style: TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'La consulta estará disponible para todos los veterinarios '
            'registrados. Uno de ellos podrá tomarla para atenderla.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
              child: const Text('Admitir consulta'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      consultasActualizando.add(id);
    });

    try {
      await supabase.rpc(
        'cambiar_estado_consulta',
        params: {'p_consulta_id': id, 'p_estado': 'Admitida'},
      );

      await cargarConsultas(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta admitida. Los veterinarios ya pueden verla.'),
          backgroundColor: verde,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL ADMITIR CONSULTA: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeErrorConsulta(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          consultasActualizando.remove(id);
        });
      }
    }
  }

  /// El administrador solamente responde consultas administrativas.
  Future<void> responderConsulta(Map<String, dynamic> consulta) async {
    final id = int.tryParse(consulta['id'].toString());

    if (id == null) return;

    final tipo = consulta['tipo']?.toString() ?? 'Administrativa';
    final estado = consulta['estado']?.toString() ?? 'Pendiente';

    if (tipo != 'Administrativa' || estado != 'Pendiente') {
      return;
    }

    final controller = TextEditingController();

    final respuesta = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Responder consulta',
            style: TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Respuesta para el cliente',
                alignLabelWithHint: true,
                hintText: 'Escribe la respuesta para el cliente.',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final texto = controller.text.trim();

                if (texto.length < 10) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La respuesta debe tener al menos 10 caracteres.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, texto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar respuesta'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (respuesta == null || !mounted) return;

    setState(() {
      consultasActualizando.add(id);
    });

    try {
      await supabase.rpc(
        'responder_consulta',
        params: {'p_consulta_id': id, 'p_respuesta': respuesta},
      );

      await cargarConsultas(mostrarCarga: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respuesta enviada al cliente.'),
          backgroundColor: verde,
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL RESPONDER CONSULTA: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeErrorConsulta(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          consultasActualizando.remove(id);
        });
      }
    }
  }

  String _mensajeErrorConsulta(Object e) {
    if (e is PostgrestException && e.code == 'P0001') {
      var mensaje = e.message.trim();

      if (mensaje.toUpperCase().startsWith('ERROR:')) {
        mensaje = mensaje.substring(6).trim();
      }

      if (mensaje.isNotEmpty) return mensaje;
    }

    return 'No se pudo completar la operación.';
  }

  /// Escucha consultas nuevas y modificaciones de estado.
  void escucharConsultas() {
    _canalConsultas = supabase
        .channel('consultas-administrador')
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

  Future<void> contactarWhatsApp(String telefono) async {
    String numero = telefono.replaceAll(RegExp(r'[^0-9]'), '');

    if (numero.length == 8) {
      numero = '591$numero';
    }

    final uri = Uri.parse('https://wa.me/$numero');

    try {
      final abierto = await launchUrl(
        uri,
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
      debugPrint('ERROR AL ABRIR WHATSAPP: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String fechaConsulta(dynamic valor) {
    if (valor == null) return 'Fecha no disponible';

    final fecha = DateTime.tryParse(valor.toString());

    if (fecha == null) return 'Fecha no disponible';

    final local = fecha.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} - '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void mostrarDetalle(Map<String, dynamic> consulta) {
    final nombre = consulta['nombre']?.toString() ?? 'Sin nombre';
    final telefono = consulta['telefono']?.toString() ?? '';
    final mensaje = consulta['mensaje']?.toString() ?? '';
    final respuesta = consulta['respuesta']?.toString() ?? '';
    final tipo = consulta['tipo']?.toString() ?? 'Administrativa';
    final estado = consulta['estado']?.toString() ?? 'Pendiente';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.message_rounded, color: verde),
              SizedBox(width: 10),
              Expanded(child: Text('Detalle de consulta')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cliente',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Teléfono',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(telefono),
                const SizedBox(height: 15),
                const Text(
                  'Tipo de consulta',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(tipo),
                const SizedBox(height: 15),
                const Text(
                  'Estado',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(estado),
                const SizedBox(height: 15),
                const Text(
                  'Fecha',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(fechaConsulta(consulta['created_at'])),
                const SizedBox(height: 15),
                const Text(
                  'Mensaje',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(mensaje),
                ),
                if (respuesta.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Respuesta enviada',
                    style: TextStyle(
                      color: verde,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(respuesta),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            if (telefono.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  contactarWhatsApp(telefono);
                },
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'Admitida':
        return Colors.teal;
      case 'En atención':
        return Colors.blue;
      case 'Atendida':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  IconData iconoEstado(String estado) {
    switch (estado) {
      case 'Admitida':
        return Icons.assignment_turned_in_rounded;
      case 'En atención':
        return Icons.medical_services_outlined;
      case 'Atendida':
        return Icons.check_circle_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String descripcionEstado(String estado, bool veterinaria) {
    if (veterinaria) {
      switch (estado) {
        case 'Admitida':
          return 'Disponible para los veterinarios';
        case 'En atención':
          return 'Un veterinario está atendiendo la consulta';
        case 'Atendida':
          return 'El veterinario ya respondió';
        default:
          return 'Esperando revisión del administrador';
      }
    }

    switch (estado) {
      case 'Atendida':
        return 'Respuesta enviada al cliente';
      default:
        return 'Esperando respuesta del administrador';
    }
  }

  Widget tarjetaConsulta(Map<String, dynamic> consulta) {
    final nombre = consulta['nombre']?.toString() ?? 'Sin nombre';
    final telefono = consulta['telefono']?.toString() ?? '';
    final mensaje = consulta['mensaje']?.toString() ?? '';
    final id = int.tryParse(consulta['id'].toString());
    final estado = consulta['estado']?.toString() ?? 'Pendiente';
    final tipo = (consulta['tipo'] ?? 'Administrativa').toString();

    final veterinaria = tipo == 'Veterinaria';
    final pendiente = estado == 'Pendiente';
    final actualizando = id != null && consultasActualizando.contains(id);

    final puedeResponder = !veterinaria && pendiente;
    final puedeAdmitir = veterinaria && pendiente;

    final color = colorEstado(estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: InkWell(
        onTap: () => mostrarDetalle(consulta),
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.message_rounded, color: verde),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          telefono,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: verde,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(iconoEstado(estado), color: color, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    estado,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Text(
                  descripcionEstado(estado, veterinaria),
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: veterinaria
                          ? Colors.teal.shade50
                          : Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: veterinaria
                            ? Colors.teal.shade200
                            : Colors.deepPurple.shade100,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          veterinaria
                              ? Icons.pets_outlined
                              : Icons.admin_panel_settings_outlined,
                          size: 13,
                          color: veterinaria
                              ? Colors.teal.shade700
                              : Colors.deepPurple,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          veterinaria ? 'Veterinaria' : 'Administrativa',
                          style: TextStyle(
                            color: veterinaria
                                ? Colors.teal.shade700
                                : Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mensaje,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Colors.black45,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      fechaConsulta(consulta['created_at']),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (puedeAdmitir)
                    TextButton.icon(
                      onPressed: id == null || actualizando
                          ? null
                          : () => admitirConsulta(consulta),
                      icon: actualizando
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 17,
                            ),
                      label: const Text('Admitir'),
                      style: TextButton.styleFrom(foregroundColor: verde),
                    ),
                  if (puedeResponder)
                    TextButton.icon(
                      onPressed: id == null || actualizando
                          ? null
                          : () => responderConsulta(consulta),
                      icon: actualizando
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.reply_rounded, size: 17),
                      label: const Text('Responder'),
                      style: TextButton.styleFrom(foregroundColor: verde),
                    ),
                  TextButton.icon(
                    onPressed: telefono.isEmpty
                        ? null
                        : () => contactarWhatsApp(telefono),
                    icon: const Icon(Icons.chat_rounded, size: 17),
                    label: const Text('WhatsApp'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF168B4B),
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

  Widget tarjetaIndicador({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE8EEE9)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              '$cantidad',
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buscador() {
    return TextField(
      controller: busquedaController,
      onChanged: (valor) {
        setState(() {
          textoBusqueda = valor;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, teléfono o mensaje...',
        prefixIcon: const Icon(Icons.search_rounded, color: verde),
        suffixIcon: textoBusqueda.isNotEmpty
            ? IconButton(
                onPressed: () {
                  busquedaController.clear();
                  setState(() {
                    textoBusqueda = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5ECE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5ECE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: verde, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalConsultas != null) {
      supabase.removeChannel(_canalConsultas!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Text(
          'Gestión de consultas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => cargarConsultas(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: verde,
        onRefresh: cargarConsultas,
        child: cargando
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(child: CircularProgressIndicator(color: verde)),
                ],
              )
            : error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 150),
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  Center(child: Text(error!)),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => cargarConsultas(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: verde,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mark_email_unread_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Consultas recibidas',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$totalConsultas',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Total',
                        cantidad: totalConsultas,
                        icono: Icons.message_rounded,
                        color: verde,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Pendientes',
                        cantidad: consultasPendientes,
                        icono: Icons.pending_actions_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'En proceso',
                        cantidad: consultasEnProceso,
                        icono: Icons.medical_services_outlined,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Atendidas',
                        cantidad: consultasAtendidas,
                        icono: Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  buscador(),
                  const SizedBox(height: 17),
                  if (consultasFiltradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 55),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            color: Colors.black26,
                            size: 55,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No hay consultas para mostrar',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      '${consultasFiltradas.length} consultas encontradas',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...consultasFiltradas.map(tarjetaConsulta),
                  ],
                ],
              ),
      ),
    );
  }
}
