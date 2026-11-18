import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/features/veterinario/screens/detalle_mascota_veterinario.dart';
import 'package:petcare_santa_cruz/features/veterinario/screens/citas_veterinario.dart';
import 'package:petcare_santa_cruz/features/notificaciones/screens/notificaciones.dart';
import 'package:petcare_santa_cruz/features/veterinario/screens/consultas_veterinario.dart';

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

  RealtimeChannel? _canalMascotas;
  RealtimeChannel? _canalNotificaciones;

  List<Map<String, dynamic>> mascotas = [];

  int selectedIndex = 0;
  int notificacionesNoLeidas = 0;

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

  String get usuarioId => supabase.auth.currentUser?.id ?? '';

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
    _escucharMascotas();
    _cargarNotificacionesVeterinario();
    _escucharNotificacionesVeterinario();
  }

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalMascotas != null) {
      supabase.removeChannel(_canalMascotas!);
    }

    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  void cambiarPantalla(int index) {
    setState(() {
      selectedIndex = index;
    });

    if (index == 3) {
      cargarMascotas(mostrarCarga: false);
    }
  }

  void _escucharMascotas() {
    _canalMascotas = supabase
        .channel('mascotas-panel-veterinario')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) {
            cargarMascotas(mostrarCarga: false);
          },
        )
        .subscribe();
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

  Future<void> cargarMascotas({bool mostrarCarga = true}) async {
    if (!mounted) return;

    if (mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

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
        error = null;
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

  Future<void> abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
    );

    if (!mounted) return;
    _cargarNotificacionesVeterinario();
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
        title: Row(
          children: [
            const Icon(Icons.pets_rounded, size: 25),
            const SizedBox(width: 10),
            Text(
              switch (selectedIndex) {
                1 => 'Gestión de citas',
                2 => 'Consultas veterinarias',
                3 => 'Mis pacientes',
                _ => 'PetCare Veterinario',
              },
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: abrirNotificaciones,
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
            tooltip: 'Cerrar sesión',
            onPressed: cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          inicioPage(),
          const CitasVeterinarioScreen(),
          const ConsultasVeterinarioScreen(),
          pacientesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: cambiarPantalla,
        backgroundColor: Colors.white,
        indicatorColor: verdeClaro,
        elevation: 3,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: verde),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: verde),
            label: 'Citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.question_answer_outlined),
            selectedIcon: Icon(Icons.question_answer_rounded, color: verde),
            label: 'Consultas',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets_rounded, color: verde),
            label: 'Pacientes',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // INICIO
  // --------------------------------------------------

  Widget inicioPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
              children: [
                encabezado(),
                const SizedBox(height: 20),
                resumenMascotas(),
                const SizedBox(height: 25),
                tituloSeccion(
                  'Accesos principales',
                  'Gestiona las actividades de tu jornada.',
                ),
                const SizedBox(height: 15),
                accesoPrincipal(
                  titulo: 'Gestión de citas',
                  descripcion: 'Revisa, confirma y atiende las reservas.',
                  icono: Icons.calendar_month_rounded,
                  color: verde,
                  fondoIcono: verdeClaro,
                  onTap: () => cambiarPantalla(1),
                ),
                const SizedBox(height: 12),
                accesoPrincipal(
                  titulo: 'Consultas veterinarias',
                  descripcion: 'Revisa y responde las consultas de clientes.',
                  icono: Icons.question_answer_rounded,
                  color: const Color(0xFF315B9A),
                  fondoIcono: const Color(0xFFEAF0FA),
                  onTap: () => cambiarPantalla(2),
                ),
                const SizedBox(height: 12),
                accesoPrincipal(
                  titulo: 'Directorio de pacientes',
                  descripcion:
                      'Consulta las fichas de las mascotas registradas.',
                  icono: Icons.pets_rounded,
                  color: const Color(0xFF9A6A22),
                  fondoIcono: const Color(0xFFFFF3DF),
                  onTap: () => cambiarPantalla(3),
                ),
                const SizedBox(height: 25),
                tarjetaConsejo(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget encabezado() {
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [verde, Color(0xFF258456)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: verde.withValues(alpha: 0.18),
            blurRadius: 15,
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
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '¡Bienvenido!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Gestiona la atención y el cuidado de tus pacientes.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
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
              size: 39,
            ),
          ),
        ],
      ),
    );
  }

  Widget resumenMascotas() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.pets_rounded, color: verde, size: 29),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pacientes registrados',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${mascotas.length}',
                  style: const TextStyle(
                    color: verde,
                    fontWeight: FontWeight.bold,
                    fontSize: 27,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: verde, size: 27),
        ],
      ),
    );
  }

  Widget accesoPrincipal({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
    required Color fondoIcono,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EEE9)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  Widget tarjetaConsejo() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF3E5C5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF9A6A22),
            size: 23,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Recuerda revisar tus citas y consultas para brindar una atención oportuna a cada paciente.',
              style: TextStyle(
                color: Color(0xFF76551F),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // PACIENTES
  // --------------------------------------------------

  Widget pacientesPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: RefreshIndicator(
              color: verde,
              onRefresh: cargarMascotas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                children: [
                  encabezadoPacientes(),
                  const SizedBox(height: 20),
                  buscador(),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mascotas registradas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF26372C),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
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
                  const SizedBox(height: 14),
                  if (cargando)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: CircularProgressIndicator(color: verde),
                      ),
                    )
                  else if (error != null)
                    mensajeError()
                  else if (mascotasFiltradas.isEmpty)
                    mensajeSinResultados()
                  else
                    ...mascotasFiltradas.map(tarjetaMascota),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget encabezadoPacientes() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9A6A22), Color(0xFFC18B3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIRECTORIO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Mis pacientes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Consulta la información de las mascotas registradas.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(Icons.pets_rounded, color: Colors.white, size: 42),
        ],
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

  Widget mensajeError() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            error ?? 'Ocurrió un error.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: cargarMascotas,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
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
}
