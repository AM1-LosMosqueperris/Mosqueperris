import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificacionesScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const NotificacionesScreen({super.key, this.onOpenMenu});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _canalNotificaciones;

  bool cargando = true;
  String? error;
  List<Map<String, dynamic>> notificaciones = [];

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  void initState() {
    super.initState();
    _escucharCambios();
    cargarNotificaciones();
  }

  @override
  void dispose() {
    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  Future<void> cargarNotificaciones({bool mostrarCarga = true}) async {
    if (!mounted) return;

    setState(() {
      if (mostrarCarga) {
        cargando = true;
      }
      error = null;
    });

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión activa.');
      }

      final respuesta = await supabase
          .from('notificaciones')
          .select()
          .eq('usuario_id', usuario.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        notificaciones = List<Map<String, dynamic>>.from(respuesta);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las notificaciones.';
        cargando = false;
      });

      debugPrint('ERROR NOTIFICACIONES: $e');
    }
  }

  void _escucharCambios() {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) return;

    _canalNotificaciones = supabase
        .channel('notificaciones-cliente-${usuario.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            cargarNotificaciones(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  Future<void> marcarComoLeida(Map<String, dynamic> notificacion) async {
    if (notificacion['leida'] == true) return;

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión activa.');
      }

      final respuesta = await supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('id', notificacion['id'])
          .eq('usuario_id', usuario.id)
          .select('id');

      if (respuesta.isEmpty) {
        // El registro pudo cambiar en otra sesion: recargamos para reflejar el estado real.
        await cargarNotificaciones(mostrarCarga: false);
        return;
      }

      if (!mounted) return;

      setState(() {
        final index = notificaciones.indexWhere(
          (n) => n['id'] == notificacion['id'],
        );

        if (index != -1) {
          notificaciones[index]['leida'] = true;
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo marcar como leída.'),
          backgroundColor: Colors.red,
        ),
      );

      debugPrint('ERROR AL MARCAR NOTIFICACION: $e');
    }
  }

  Future<void> marcarTodasComoLeidas() async {
    final pendientes = notificaciones.where((n) => n['leida'] != true).toList();

    if (pendientes.isEmpty) return;

    try {
      final usuario = supabase.auth.currentUser;

      if (usuario == null) return;

      final respuesta = await supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('usuario_id', usuario.id)
          .eq('leida', false)
          .select('id');

      if (respuesta.isEmpty) {
        // No habia nada pendiente (o cambio en otra sesion): recargamos el estado real.
        await cargarNotificaciones(mostrarCarga: false);
        return;
      }

      if (!mounted) return;

      setState(() {
        for (final notificacion in notificaciones) {
          notificacion['leida'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las notificaciones fueron leídas.'),
          backgroundColor: verde,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron actualizar las notificaciones.'),
          backgroundColor: Colors.red,
        ),
      );

      debugPrint('ERROR AL MARCAR TODAS: $e');
    }
  }

  int get noLeidas => notificaciones.where((n) => n['leida'] != true).length;

  IconData iconoTipo(String? tipo) {
    switch (tipo) {
      case 'reserva':
        return Icons.calendar_month_outlined;
      case 'historial_medico':
        return Icons.medical_services_outlined;
      case 'consulta_admin':
        return Icons.contact_support_outlined;
      case 'consulta_admitida':
        return Icons.assignment_turned_in_outlined;
      case 'consulta_atendida':
        return Icons.mark_email_read_outlined;
      case 'reserva_admin':
        return Icons.admin_panel_settings_outlined;
      case 'reserva_veterinario':
        return Icons.medical_information_outlined;
      case 'usuario_nuevo':
        return Icons.person_add_alt_outlined;
      case 'pedido_admin':
        return Icons.shopping_bag_outlined;
      case 'pedido_estado':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color colorTipo(String? tipo) {
    switch (tipo) {
      case 'reserva':
        return Colors.blue;
      case 'historial_medico':
        return verde;
      case 'consulta_admin':
        return Colors.deepPurple;
      case 'consulta_admitida':
        return Colors.orange;
      case 'consulta_atendida':
        return Colors.green;
      case 'reserva_admin':
        return Colors.teal;
      case 'reserva_veterinario':
        return Colors.indigo;
      case 'usuario_nuevo':
        return Colors.blueGrey;
      case 'pedido_admin':
        return Colors.deepOrange;
      case 'pedido_estado':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String formatoFecha(dynamic fecha) {
    if (fecha == null) return '';

    try {
      final date = DateTime.parse(fecha.toString()).toLocal();

      final dia = date.day.toString().padLeft(2, '0');
      final mes = date.month.toString().padLeft(2, '0');
      final anio = date.year;
      final hora = date.hour.toString().padLeft(2, '0');
      final minuto = date.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$anio • $hora:$minuto';
    } catch (_) {
      return '';
    }
  }

  Widget construirNotificacion(Map<String, dynamic> notificacion) {
    final leida = notificacion['leida'] == true;
    final tipo = notificacion['tipo']?.toString();

    return Card(
      elevation: leida ? 0 : 2,
      color: leida ? Colors.white : verdeClaro,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: leida ? Colors.grey.shade200 : verde.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => marcarComoLeida(notificacion),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colorTipo(tipo).withValues(alpha: 0.12),
                child: Icon(iconoTipo(tipo), color: colorTipo(tipo), size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notificacion['titulo']?.toString() ??
                                'Notificación',
                            style: TextStyle(
                              fontWeight: leida
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF26352B),
                            ),
                          ),
                        ),
                        if (!leida)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: verde,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      notificacion['mensaje']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatoFecha(notificacion['created_at']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget contenidoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 75,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 18),
            const Text(
              'No tienes notificaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí aparecerán los avisos sobre tus citas y la atención de tus mascotas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: verde,
        elevation: 0,
        leading: widget.onOpenMenu != null
            ? IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu),
                tooltip: 'Abrir menú',
              )
            : null,
        title: const Text(
          'Notificaciones',
          style: TextStyle(color: verde, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (noLeidas > 0)
            IconButton(
              onPressed: marcarTodasComoLeidas,
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
            ),
        ],
      ),
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
                      Icons.error_outline,
                      color: Colors.red,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: cargarNotificaciones,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: cargarNotificaciones,
              color: verde,
              child: notificaciones.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: contenidoVacio(),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          noLeidas == 0
                              ? 'Todas tus notificaciones están leídas'
                              : 'Tienes $noLeidas notificación(es) sin leer',
                          style: const TextStyle(
                            color: verde,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ...notificaciones.map(construirNotificacion),
                      ],
                    ),
            ),
    );
  }
}
