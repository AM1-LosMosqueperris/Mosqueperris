import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'detalle_mascota_veterinario.dart';
import 'citas_veterinario.dart';
import 'notificaciones.dart';

class PanelVeterinarioScreen extends StatefulWidget {
  const PanelVeterinarioScreen({super.key});

  @override
  State<PanelVeterinarioScreen> createState() => _PanelVeterinarioScreenState();
}

class _PanelVeterinarioScreenState extends State<PanelVeterinarioScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final supabase = Supabase.instance.client;
  final TextEditingController busquedaController = TextEditingController();

  List<Map<String, dynamic>> mascotas = [];
  int notificacionesNoLeidas = 0;
  RealtimeChannel? _canalNotificaciones;

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

  List<Map<String, dynamic>> get mascotasFiltradas {
    if (textoBusqueda.trim().isEmpty) return mascotas;

    final busqueda = textoBusqueda.toLowerCase().trim();

    return mascotas.where((mascota) {
      final nombre = (mascota['nombre'] ?? '').toString().toLowerCase();
      final especie = (mascota['especie'] ?? '').toString().toLowerCase();
      final raza = (mascota['raza'] ?? '').toString().toLowerCase();
      final propietario = (mascota['propietario'] ?? '')
          .toString()
          .toLowerCase();

      return nombre.contains(busqueda) ||
          especie.contains(busqueda) ||
          raza.contains(busqueda) ||
          propietario.contains(busqueda);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarMascotas();
    _cargarNotificacionesVeterinario();
    _escucharNotificacionesVeterinario();
  }

  Future<void> _cargarNotificacionesVeterinario() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) return;

    try {
      final datos = await supabase
          .from('notificaciones')
          .select('id')
          .eq('usuario_id', usuario.id)
          .eq('leida', false);

      if (!mounted) return;

      setState(() {
        notificacionesNoLeidas = datos.length;
      });
    } catch (e) {
      debugPrint('Error al cargar notificaciones: $e');
    }
  }

  void _escucharNotificacionesVeterinario() {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) return;

    _canalNotificaciones = supabase
        .channel('notificaciones-veterinario-${usuario.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            if (!mounted) return;

            if (payload.newRecord['leida'] == false) {
              setState(() {
                notificacionesNoLeidas++;
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            _cargarNotificacionesVeterinario();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  Future<void> cargarMascotas() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await supabase
          .from('mascotas')
          .select(
            'id, nombre, especie, raza, fecha_nacimiento, sexo, peso, '
            'observaciones, propietario, usuario_id',
          )
          .order('nombre');

      if (!mounted) return;

      setState(() {
        mascotas = List<Map<String, dynamic>>.from(datos);
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR MASCOTAS: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar las mascotas.';
        cargando = false;
      });
    }
  }

  void abrirGestionCitas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CitasVeterinarioScreen()),
    );
  }

  Future<void> cerrarSesion() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void abrirDetalle(Map<String, dynamic> mascota) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleMascotaVeterinarioScreen(mascota: mascota),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Text(
          'Panel veterinario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificacionesScreen(),
                ),
              );

              _cargarNotificacionesVeterinario();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (notificacionesNoLeidas > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        notificacionesNoLeidas > 99
                            ? '99+'
                            : '$notificacionesNoLeidas',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: abrirGestionCitas,
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Gestionar citas',
          ),
          IconButton(
            onPressed: cargarMascotas,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: verde,
        onRefresh: cargarMascotas,
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
                  const SizedBox(height: 140),
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.redAccent,
                    size: 55,
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: cargarMascotas,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                children: [
                  encabezado(),

                  const SizedBox(height: 20),

                  resumenMascotas(),

                  const SizedBox(height: 20),

                  accesoCitas(),

                  const SizedBox(height: 25),

                  tituloSeccion(
                    'Directorio de mascotas',
                    'Consulta la información de tus pacientes',
                  ),

                  const SizedBox(height: 15),

                  buscador(),

                  const SizedBox(height: 17),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mascotas registradas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF26372C),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: verdeClaro,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${mascotasFiltradas.length} resultados',
                          style: const TextStyle(
                            color: verde,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (mascotasFiltradas.isEmpty)
                    mensajeSinResultados()
                  else
                    ...mascotasFiltradas.map(tarjetaMascota),
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
                  'ÁREA PROFESIONAL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Bienvenido, veterinario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Gestiona la atención y el cuidado de tus pacientes.',
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
              Icons.medical_services_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget resumenMascotas() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.pets_rounded, color: verde, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pacientes registrados',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  '${mascotas.length}',
                  style: const TextStyle(
                    color: verde,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: verde, size: 25),
        ],
      ),
    );
  }

  Widget accesoCitas() {
    return InkWell(
      onTap: abrirGestionCitas,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: verdeClaro,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD6EBDD)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: verde,
                size: 27,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de citas',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Revisa y administra las reservas',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: verde, size: 17),
          ],
        ),
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
            color: Color(0xFF26372C),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitulo,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
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
        hintText: 'Buscar mascota o propietario...',
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE5ECE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE5ECE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: verde, width: 1.5),
        ),
      ),
    );
  }

  Widget tarjetaMascota(Map<String, dynamic> mascota) {
    final nombre = mascota['nombre']?.toString() ?? 'Sin nombre';
    final especie = mascota['especie']?.toString() ?? '';
    final raza = mascota['raza']?.toString() ?? '';
    final propietario = mascota['propietario']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => abrirDetalle(mascota),
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.pets_rounded, color: verde, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF26372C),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        especie,
                        if (raza.isNotEmpty) raza,
                      ].where((dato) => dato.isNotEmpty).join(' • '),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if (propietario.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: verde,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              propietario,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: verde,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mensajeSinResultados() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: verdeClaro,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: verde, size: 35),
          ),
          const SizedBox(height: 13),
          const Text(
            'No se encontraron mascotas',
            style: TextStyle(
              color: verde,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba con otro nombre, especie, raza o propietario.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
