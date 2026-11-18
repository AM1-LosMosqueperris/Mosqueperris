import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/utils/fechas.dart';
import 'package:petcare_santa_cruz/features/clima/screens/clima_screen.dart';
import 'package:petcare_santa_cruz/features/cliente/screens/mapa_negocios.dart';

class InicioScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onOpenMenu;

  const InicioScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenMenu,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeOscuro = Color(0xFF10452E);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7F9F6);
  static const Color texto = Color(0xFF26352C);

  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? errorCarga;

  int totalMascotas = 0;
  int totalCitas = 0;
  int totalVacunas = 0;
  int notificacionesNoLeidas = 0;

  List<Map<String, dynamic>> proximasCitas = [];
  RealtimeChannel? _canalNotificaciones;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
    _escucharNotificaciones();
  }

  void _escucharNotificaciones() {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) return;

    _canalNotificaciones = supabase
        .channel('resumen-${usuario.id}')
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
            debugPrint('CAMBIO EN MASCOTAS: ${payload.eventType}');
            _cargarResumen(mostrarCarga: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            debugPrint('CAMBIO EN RESERVAS: ${payload.eventType}');
            _cargarResumen(mostrarCarga: false);
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
            debugPrint('CAMBIO EN HISTORIAL: ${payload.eventType}');
            _cargarResumen(mostrarCarga: false);
          },
        )
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
            debugPrint('CAMBIO EN NOTIFICACIONES: ${payload.eventType}');
            _cargarResumen(mostrarCarga: false);
          },
        )
        .subscribe();
  }

  Future<void> _cargarResumen({bool mostrarCarga = true}) async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      setState(() {
        cargando = false;
        errorCarga = 'No hay una sesión activa.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        if (mostrarCarga) {
          cargando = true;
        }
        errorCarga = null;
      });
    }

    try {
      final resultados = await Future.wait([
        supabase.from('mascotas').select('id').eq('usuario_id', usuario.id),

        supabase
            .from('reservas')
            .select('id, fecha, hora, estado, mascota, servicio')
            .eq('usuario_id', usuario.id),

        supabase
            .from('historial_medico')
            .select('id, vacuna')
            .eq('usuario_id', usuario.id)
            .not('vacuna', 'is', null)
            .neq('vacuna', ''),
        supabase
            .from('notificaciones')
            .select('id')
            .eq('usuario_id', usuario.id)
            .eq('leida', false),
      ]);

      final mascotas = List<Map<String, dynamic>>.from(resultados[0]);

      final reservas = List<Map<String, dynamic>>.from(resultados[1]);

      final vacunas = List<Map<String, dynamic>>.from(resultados[2]);
      final notificaciones = List<Map<String, dynamic>>.from(resultados[3]);

      final citasActivas = reservas.where((reserva) {
        final estado = reserva['estado']?.toString().toLowerCase().trim();

        return estado != 'cancelada' && estado != 'cancelado';
      }).toList();

      final ahora = DateTime.now();

      final citasFuturas = citasActivas.where((reserva) {
        final fechaHora = Fechas.tryParseFechaHora(
          reserva['fecha'],
          reserva['hora'],
        );

        if (fechaHora == null) return false;

        return fechaHora.isAfter(ahora);
      }).toList();

      citasFuturas.sort((a, b) {
        final fechaA = Fechas.tryParseFechaHora(a['fecha'], a['hora']);
        final fechaB = Fechas.tryParseFechaHora(b['fecha'], b['hora']);

        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return 1;
        if (fechaB == null) return -1;

        return fechaA.compareTo(fechaB);
      });

      if (!mounted) return;

      setState(() {
        totalMascotas = mascotas.length;
        totalCitas = citasActivas.length;
        totalVacunas = vacunas.length;
        notificacionesNoLeidas = notificaciones.length;

        proximasCitas = citasFuturas.take(3).toList();

        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR RESUMEN: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        errorCarga = 'No se pudieron cargar tus datos.';
      });
    }
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '';

    try {
      final partes = fecha.toString().split('-');

      if (partes.length != 3) return fecha.toString();

      return '${partes[2]}/${partes[1]}/${partes[0]}';
    } catch (_) {
      return fecha.toString();
    }
  }

  String _formatearHora(dynamic hora) {
    if (hora == null) return '';

    final valor = hora.toString();

    if (valor.length >= 5) {
      return valor.substring(0, 5);
    }

    return valor;
  }

  @override
  void dispose() {
    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: fondo,
        foregroundColor: verde,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.pets, size: 27),
            SizedBox(width: 10),
            Text(
              'PetCare',
              style: TextStyle(
                color: verde,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 5),
            Text(
              'SANTA CRUZ',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            color: verde,
            tooltip: 'Notificaciones',
            onPressed: () => widget.onNavigate(9),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, size: 26),
                if (notificacionesNoLeidas > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        notificacionesNoLeidas > 99
                            ? '99+'
                            : notificacionesNoLeidas.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            color: verde,
            tooltip: 'Abrir menú',
            onPressed: widget.onOpenMenu,
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        color: verde,
        onRefresh: _cargarResumen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hola, bienvenido 👋',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                '¡Tu mascota merece lo mejor!',
                style: TextStyle(
                  fontSize: 23,
                  color: texto,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 20),

              // TARJETA PRINCIPAL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [verde, verdeOscuro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: verde.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      top: 5,
                      child: Icon(
                        Icons.pets,
                        size: 115,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CUIDADO Y BIENESTAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 17),

                        const Text(
                          'Su salud es nuestra\nprioridad.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Todo lo que necesitas para cuidar\na tu compañero está aquí.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigate(2),
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: const Text(
                            'Explorar servicios',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: verde,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // RESUMEN
              _tituloSeccion('Tu resumen', 'Un vistazo a tus cuidados'),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _estadistica(
                      'Mascotas',
                      totalMascotas,
                      Icons.pets,
                      const Color(0xFFE8F5ED),
                      verde,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _estadistica(
                      'Citas',
                      totalCitas,
                      Icons.calendar_month,
                      const Color(0xFFEAF0FF),
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _estadistica(
                      'Vacunas',
                      totalVacunas,
                      Icons.vaccines,
                      const Color(0xFFFFF1E5),
                      Colors.deepOrange,
                    ),
                  ),
                ],
              ),

              if (errorCarga != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        errorCarga!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cargarResumen,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // ACCESOS RAPIDOS
              _tituloSeccion(
                '¿Qué necesitas hoy?',
                'Accede rápidamente a nuestras funciones',
              ),

              const SizedBox(height: 15),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _accesoRapido(
                    'Mis mascotas',
                    'Gestiona sus perfiles',
                    Icons.pets,
                    verde,
                    verdeClaro,
                    () => widget.onNavigate(1),
                  ),
                  _accesoRapido(
                    'Reservar cita',
                    'Agenda una atención',
                    Icons.calendar_month,
                    Colors.blue,
                    const Color(0xFFEAF0FF),
                    () => widget.onNavigate(3),
                  ),
                  _accesoRapido(
                    'Vacunas',
                    'Control de vacunación',
                    Icons.vaccines,
                    Colors.deepOrange,
                    const Color(0xFFFFF1E5),
                    () => widget.onNavigate(4),
                  ),
                  _accesoRapido(
                    'Historial médico',
                    'Consulta sus registros',
                    Icons.medical_information,
                    Colors.purple,
                    const Color(0xFFF2EAFE),
                    () => widget.onNavigate(5),
                  ),
                  _accesoRapido(
                    'Clima',
                    'Consulta el clima de Santa Cruz',
                    Icons.wb_sunny,
                    Colors.orange,
                    const Color(0xFFFFF3E0),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClimaScreen()),
                      );
                    },
                  ),
                  _accesoRapido(
                    'Mapa de veterinarias',
                    'Encuentra establecimientos cercanos',
                    Icons.map_outlined,
                    Colors.green,
                    const Color(0xFFE8F5ED),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MapaNegociosScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // PROXIMAS CITAS
              _tituloSeccion(
                'Próximas citas',
                'Mantente al día con su atención',
              ),

              const SizedBox(height: 14),

              if (cargando)
                _contenedorCitas(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 25),
                    child: Center(
                      child: CircularProgressIndicator(color: verde),
                    ),
                  ),
                )
              else if (proximasCitas.isEmpty)
                _contenedorCitas(
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: const BoxDecoration(
                          color: verdeClaro,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_available,
                          color: verde,
                          size: 30,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Tus citas aparecerán aquí',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: texto,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Cuando reserves una atención veterinaria, '
                        'podrás consultar sus detalles desde esta sección.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton(
                        onPressed: () => widget.onNavigate(3),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: verde,
                          side: const BorderSide(color: verde),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reservar una cita'),
                      ),
                    ],
                  ),
                )
              else
                _contenedorCitas(
                  Column(
                    children: [
                      for (int i = 0; i < proximasCitas.length; i++) ...[
                        if (i > 0) const Divider(height: 25),
                        _tarjetaCita(proximasCitas[i]),
                      ],

                      const SizedBox(height: 12),

                      OutlinedButton(
                        onPressed: () => widget.onNavigate(3),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: verde,
                          side: const BorderSide(color: verde),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Ver mis citas'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 25),

              // MENSAJE FINAL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5ED),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.favorite, color: verde, size: 25),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El amor también se demuestra cuidando su salud. '
                        '¡Gracias por confiar en PetCare!',
                        style: TextStyle(
                          color: verdeOscuro,
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _contenedorCitas(Widget contenido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: contenido,
    );
  }

  Widget _tarjetaCita(Map<String, dynamic> cita) {
    final mascota = cita['mascota']?.toString();
    final servicio = cita['servicio']?.toString();
    final fecha = _formatearFecha(cita['fecha']);
    final hora = _formatearHora(cita['hora']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: verdeClaro,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event, color: verde, size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                servicio != null && servicio.isNotEmpty
                    ? servicio
                    : 'Atención veterinaria',
                style: const TextStyle(
                  color: texto,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              if (mascota != null && mascota.isNotEmpty)
                Text(
                  'Mascota: $mascota',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 13, color: verde),
                  const SizedBox(width: 5),
                  Text(
                    fecha,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 13, color: verde),
                  const SizedBox(width: 5),
                  Text(
                    hora,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tituloSeccion(String titulo, String subtitulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: texto,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitulo,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _estadistica(
    String titulo,
    int cantidad,
    IconData icono,
    Color fondoIcono,
    Color colorIcono,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: fondoIcono,
            child: Icon(icono, color: colorIcono, size: 21),
          ),
          const SizedBox(height: 10),
          Text(
            cargando ? '...' : cantidad.toString(),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: texto,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accesoRapido(
    String titulo,
    String descripcion,
    IconData icono,
    Color color,
    Color fondoIcono,
    VoidCallback accion,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: accion,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: fondoIcono,
                child: Icon(icono, color: color, size: 23),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: texto,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
