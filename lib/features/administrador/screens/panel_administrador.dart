import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/features/administrador/screens/gestion_servicios.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_mascotas.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_reservas_admin.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/reportes_admin.dart';
import 'package:petcare_santa_cruz/features/notificaciones/screens/notificaciones.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_consultas_admin.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_productos.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_pedidos_admin.dart';

class PanelAdministradorScreen extends StatefulWidget {
  const PanelAdministradorScreen({super.key});

  @override
  State<PanelAdministradorScreen> createState() =>
      _PanelAdministradorScreenState();
}

class _PanelAdministradorScreenState extends State<PanelAdministradorScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final supabase = Supabase.instance.client;
  final TextEditingController busquedaController = TextEditingController();

  List<Map<String, dynamic>> usuarios = [];

  int totalMascotas = 0;
  int totalReservas = 0;
  int reservasAtendidas = 0;
  int notificacionesNoLeidas = 0;

  int selectedIndex = 0;

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

  RealtimeChannel? _canalNotificaciones;
  RealtimeChannel? _canalResumen;

  int get totalClientes => usuarios.where((u) => u['rol'] == 'cliente').length;

  int get totalVeterinarios =>
      usuarios.where((u) => u['rol'] == 'veterinario').length;

  int get totalAdministradores =>
      usuarios.where((u) => u['rol'] == 'administrador').length;

  List<Map<String, dynamic>> get usuariosFiltrados {
    if (textoBusqueda.trim().isEmpty) return usuarios;

    final busqueda = textoBusqueda.toLowerCase().trim();

    return usuarios.where((usuario) {
      final nombre = (usuario['nombre'] ?? '').toString().toLowerCase();
      final rol = (usuario['rol'] ?? '').toString().toLowerCase();
      final id = (usuario['id'] ?? '').toString().toLowerCase();

      return nombre.contains(busqueda) ||
          rol.contains(busqueda) ||
          id.contains(busqueda);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarUsuarios();
    _escucharResumen();
    _cargarNotificacionesAdmin();
    _escucharNotificacionesAdmin();
  }

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalResumen != null) {
      supabase.removeChannel(_canalResumen!);
    }

    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  void cambiarSeccion(int index) {
    setState(() {
      selectedIndex = index;
    });

    if (index == 2) {
      cargarUsuarios(mostrarCarga: false);
    }

    if (index == 0) {
      cargarEstadisticas();
    }
  }

  void _escucharResumen() {
    _canalResumen = supabase
        .channel('resumen-administrador')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'perfiles',
          callback: (payload) {
            cargarUsuarios(mostrarCarga: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) {
            cargarEstadisticas();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservas',
          callback: (payload) {
            cargarEstadisticas();
          },
        )
        .subscribe();
  }

  Future<void> _cargarNotificacionesAdmin() async {
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

  void _escucharNotificacionesAdmin() {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;

    _canalNotificaciones = supabase
        .channel('notificaciones-admin-${usuario.id}')
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
            _cargarNotificacionesAdmin();
          },
        )
        .subscribe();
  }

  Future<void> cargarUsuarios({bool mostrarCarga = true}) async {
    if (!mounted) return;

    if (mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final datos = await supabase.rpc('listar_perfiles_admin');

      if (!mounted) return;

      setState(() {
        usuarios = (datos as List)
            .map((usuario) => Map<String, dynamic>.from(usuario as Map))
            .toList();

        cargando = false;
        error = null;
      });

      await cargarEstadisticas();
    } catch (e) {
      debugPrint('ERROR AL CARGAR USUARIOS: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar los usuarios.';
        cargando = false;
      });
    }
  }

  Future<void> cargarEstadisticas() async {
    try {
      final datos = await supabase.rpc('obtener_estadisticas_admin');

      if (!mounted) return;

      if (datos is List && datos.isNotEmpty) {
        final estadistica = Map<String, dynamic>.from(datos.first as Map);

        setState(() {
          totalMascotas = (estadistica['total_mascotas'] as num?)?.toInt() ?? 0;

          totalReservas = (estadistica['total_reservas'] as num?)?.toInt() ?? 0;

          reservasAtendidas =
              (estadistica['reservas_atendidas'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR ESTADÍSTICAS: $e');
    }
  }

  String nombreRol(String rol) {
    switch (rol) {
      case 'administrador':
        return 'Administrador';
      case 'veterinario':
        return 'Veterinario';
      case 'cliente':
        return 'Cliente';
      default:
        return rol;
    }
  }

  Color colorRol(String rol) {
    switch (rol) {
      case 'administrador':
        return Colors.purple;
      case 'veterinario':
        return Colors.orange;
      case 'cliente':
        return Colors.blue;
      default:
        return verde;
    }
  }

  IconData iconoRol(String rol) {
    switch (rol) {
      case 'administrador':
        return Icons.admin_panel_settings_rounded;
      case 'veterinario':
        return Icons.medical_services_rounded;
      case 'cliente':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  Future<void> cambiarRol(Map<String, dynamic> usuario) async {
    final String rolActual = usuario['rol']?.toString() ?? 'cliente';
    final String usuarioId = usuario['id'].toString();

    String rolSeleccionado = rolActual;

    final nuevoRol = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, actualizarDialogo) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.manage_accounts_rounded, color: verde),
                  SizedBox(width: 10),
                  Text('Cambiar rol'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario['nombre']?.toString().isNotEmpty == true
                        ? usuario['nombre'].toString()
                        : 'Usuario sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  const Text('Selecciona el nuevo rol:'),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: rolSeleccionado,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fondo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cliente',
                        child: Text('Cliente'),
                      ),
                      DropdownMenuItem(
                        value: 'veterinario',
                        child: Text('Veterinario'),
                      ),
                      DropdownMenuItem(
                        value: 'administrador',
                        child: Text('Administrador'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;

                      actualizarDialogo(() {
                        rolSeleccionado = valor;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, rolSeleccionado);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nuevoRol == null || nuevoRol == rolActual) return;
    if (!mounted) return;

    try {
      await supabase.rpc(
        'cambiar_rol_usuario',
        params: {'p_usuario_id': usuarioId, 'p_nuevo_rol': nuevoRol},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol actualizado correctamente.'),
          backgroundColor: verde,
        ),
      );

      await cargarUsuarios();
    } catch (e) {
      debugPrint('ERROR AL CAMBIAR ROL: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el rol del usuario.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> cerrarSesion() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
    );

    if (!mounted) return;
    _cargarNotificacionesAdmin();
  }

  void abrirPantalla(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  // --------------------------------------------------
  // NAVEGACIÓN PRINCIPAL
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        toolbarHeight: 68,
        elevation: 0,
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.pets_rounded, size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedIndex == 0
                    ? 'PetCare Administrador'
                    : selectedIndex == 1
                    ? 'Gestión'
                    : selectedIndex == 2
                    ? 'Usuarios'
                    : 'Reportes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            tooltip: 'Actualizar',
            onPressed: () {
              if (selectedIndex == 2) {
                cargarUsuarios();
              } else {
                cargarEstadisticas();
              }
            },
            icon: const Icon(Icons.refresh_rounded),
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
        children: [inicioPage(), gestionPage(), usuariosPage(), reportesPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: cambiarSeccion,
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
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded, color: verde),
            label: 'Gestión',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: verde),
            label: 'Usuarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: verde),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // INICIO
  // --------------------------------------------------

  Widget inicioPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          color: verde,
          onRefresh: () async {
            await cargarUsuarios();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            children: [
              encabezado(),
              const SizedBox(height: 24),
              tituloSeccion(
                'Resumen del sistema',
                'Indicadores generales de PetCare.',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnas = constraints.maxWidth > 600 ? 3 : 2;

                  return GridView.count(
                    crossAxisCount: columnas,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                    childAspectRatio: columnas == 3 ? 1.35 : 1.15,
                    children: [
                      tarjetaEstadistica(
                        'Usuarios',
                        usuarios.length,
                        Icons.people_alt_rounded,
                        verde,
                      ),
                      tarjetaEstadistica(
                        'Clientes',
                        totalClientes,
                        Icons.person_rounded,
                        Colors.blue,
                      ),
                      tarjetaEstadistica(
                        'Veterinarios',
                        totalVeterinarios,
                        Icons.medical_services_rounded,
                        Colors.orange,
                      ),
                      tarjetaEstadistica(
                        'Administradores',
                        totalAdministradores,
                        Icons.admin_panel_settings_rounded,
                        Colors.purple,
                      ),
                      tarjetaEstadistica(
                        'Mascotas',
                        totalMascotas,
                        Icons.pets_rounded,
                        Colors.teal,
                      ),
                      tarjetaEstadistica(
                        'Reservas',
                        totalReservas,
                        Icons.calendar_month_rounded,
                        Colors.deepOrange,
                      ),
                      tarjetaEstadistica(
                        'Atendidas',
                        reservasAtendidas,
                        Icons.medical_information_rounded,
                        Colors.indigo,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              tituloSeccion(
                'Accesos rápidos',
                'Entra directamente a las funciones principales.',
              ),
              const SizedBox(height: 14),
              accesoRapido(
                'Administrar servicios',
                'Configura los servicios disponibles.',
                Icons.medical_services_rounded,
                () => cambiarSeccion(1),
              ),
              accesoRapido(
                'Gestionar reservas',
                'Consulta y administra las reservas.',
                Icons.calendar_month_rounded,
                () => abrirPantalla(const GestionReservasAdminScreen()),
              ),
              accesoRapido(
                'Gestionar usuarios',
                'Consulta cuentas y administra sus roles.',
                Icons.people_alt_rounded,
                () => cambiarSeccion(2),
              ),
              accesoRapido(
                'Consultar reportes',
                'Revisa los indicadores y gráficos.',
                Icons.bar_chart_rounded,
                () => abrirPantalla(const ReportesAdminScreen()),
              ),
              const SizedBox(height: 15),
              tarjetaConsejo(),
            ],
          ),
        ),
      ),
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
                  'CONTROL DEL SISTEMA',
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
                  'Administra y supervisa tu aplicación PetCare.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${usuarios.length} usuarios registrados',
                    style: const TextStyle(
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
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 39,
            ),
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
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF26372C),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitulo,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget tarjetaEstadistica(
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(height: 9),
          Text(
            '$cantidad',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

  Widget accesoRapido(
    String titulo,
    String descripcion,
    IconData icono,
    VoidCallback onTap,
  ) {
    return tarjetaAcceso(
      titulo: titulo,
      descripcion: descripcion,
      icono: icono,
      onTap: onTap,
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
              'Mantén actualizada la información de la aplicación y revisa periódicamente las actividades del sistema.',
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
  // GESTIÓN
  // --------------------------------------------------

  Widget gestionPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: [
            encabezadoGestion(),
            const SizedBox(height: 23),
            tituloSeccion(
              'Módulos de administración',
              'Selecciona el apartado que deseas gestionar.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columnas = constraints.maxWidth > 600 ? 3 : 2;

                return GridView.count(
                  crossAxisCount: columnas,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columnas == 3 ? 1.05 : 0.95,
                  children: [
                    tarjetaModulo(
                      'Servicios',
                      'Administra los servicios ofrecidos.',
                      Icons.medical_services_rounded,
                      verde,
                      verdeClaro,
                      () => abrirPantalla(const GestionServiciosScreen()),
                    ),
                    tarjetaModulo(
                      'Mascotas',
                      'Consulta las mascotas registradas.',
                      Icons.pets_rounded,
                      Colors.teal,
                      const Color(0xFFE5F5F1),
                      () => abrirPantalla(const GestionMascotasScreen()),
                    ),
                    tarjetaModulo(
                      'Reservas',
                      'Revisa las reservas de los clientes.',
                      Icons.calendar_month_rounded,
                      Colors.deepOrange,
                      const Color(0xFFFFEEE5),
                      () => abrirPantalla(const GestionReservasAdminScreen()),
                    ),
                    tarjetaModulo(
                      'Consultas',
                      'Revisa los mensajes de los clientes.',
                      Icons.question_answer_rounded,
                      Colors.blue,
                      const Color(0xFFEAF1FC),
                      () => abrirPantalla(const GestionConsultasAdminScreen()),
                    ),
                    tarjetaModulo(
                      'Productos',
                      'Administra los productos de la tienda.',
                      Icons.inventory_2_rounded,
                      Colors.purple,
                      const Color(0xFFF2EAFE),
                      () => abrirPantalla(const GestionProductosScreen()),
                    ),
                    tarjetaModulo(
                      'Pedidos',
                      'Consulta compras y actualiza sus estados.',
                      Icons.shopping_bag_rounded,
                      Colors.green,
                      const Color(0xFFE8F5E9),
                      () => abrirPantalla(const GestionPedidosAdminScreen()),
                    ),
                    tarjetaModulo(
                      'Reportes',
                      'Consulta estadísticas y gráficos.',
                      Icons.bar_chart_rounded,
                      Colors.brown,
                      const Color(0xFFF4ECE5),
                      () => abrirPantalla(const ReportesAdminScreen()),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget encabezadoGestion() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF315B9A), Color(0xFF527DB8)],
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
                  'ADMINISTRACIÓN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Gestiona PetCare',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Accede a los diferentes módulos de la aplicación.',
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
          Icon(Icons.settings_rounded, color: Colors.white, size: 43),
        ],
      ),
    );
  }

  Widget tarjetaModulo(
    String titulo,
    String descripcion,
    IconData icono,
    Color color,
    Color fondoIcono,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icono, color: color, size: 26),
              ),
              const SizedBox(height: 13),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF26372C),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // USUARIOS
  // --------------------------------------------------

  Widget usuariosPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          color: verde,
          onRefresh: cargarUsuarios,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            children: [
              encabezadoUsuarios(),
              const SizedBox(height: 20),
              resumenRoles(),
              const SizedBox(height: 23),
              tituloSeccion(
                'Directorio de usuarios',
                'Busca cuentas y administra sus roles.',
              ),
              const SizedBox(height: 15),
              buscadorUsuarios(),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Usuarios registrados',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF26372C),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: verdeClaro,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${usuariosFiltrados.length} resultados',
                      style: const TextStyle(
                        color: verde,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: verde)),
                )
              else if (error != null)
                mensajeErrorUsuarios()
              else if (usuariosFiltrados.isEmpty)
                mensajeSinUsuarios()
              else
                ...usuariosFiltrados.map(tarjetaUsuario),
            ],
          ),
        ),
      ),
    );
  }

  Widget encabezadoUsuarios() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17623F), Color(0xFF258456)],
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
                  'CUENTAS Y PERMISOS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Gestión de usuarios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Consulta las cuentas y administra sus permisos.',
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
          Icon(Icons.people_alt_rounded, color: Colors.white, size: 43),
        ],
      ),
    );
  }

  Widget resumenRoles() {
    return Row(
      children: [
        Expanded(
          child: resumenRol(
            'Clientes',
            totalClientes,
            Colors.blue,
            Icons.person_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: resumenRol(
            'Veterinarios',
            totalVeterinarios,
            Colors.orange,
            Icons.medical_services_rounded,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: resumenRol(
            'Admins',
            totalAdministradores,
            Colors.purple,
            Icons.admin_panel_settings_rounded,
          ),
        ),
      ],
    );
  }

  Widget resumenRol(String titulo, int cantidad, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 23),
          const SizedBox(height: 7),
          Text(
            '$cantidad',
            style: const TextStyle(
              color: verde,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buscadorUsuarios() {
    return TextField(
      controller: busquedaController,
      onChanged: (valor) {
        setState(() {
          textoBusqueda = valor;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, rol o ID...',
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
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
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

  Widget tarjetaUsuario(Map<String, dynamic> usuario) {
    final nombre = usuario['nombre']?.toString() ?? '';
    final rol = usuario['rol']?.toString() ?? 'cliente';
    final id = usuario['id']?.toString() ?? '';

    final color = colorRol(rol);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(iconoRol(rol), color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre.isNotEmpty ? nombre : 'Usuario sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26372C),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nombreRol(rol),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID: $id',
                    style: const TextStyle(color: Colors.black45, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => cambiarRol(usuario),
              icon: const Icon(Icons.edit_rounded, color: verde),
              tooltip: 'Cambiar rol',
            ),
          ],
        ),
      ),
    );
  }

  Widget mensajeSinUsuarios() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: const Column(
        children: [
          Icon(Icons.person_search_rounded, size: 42, color: verde),
          SizedBox(height: 12),
          Text(
            'No se encontraron usuarios',
            style: TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            'Prueba con otro nombre, rol o identificador.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget mensajeErrorUsuarios() {
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
            onPressed: cargarUsuarios,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // REPORTES
  // --------------------------------------------------

  Widget reportesPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: RefreshIndicator(
          color: verde,
          onRefresh: cargarEstadisticas,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF315B9A), Color(0xFF527DB8)],
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
                            'INFORMACIÓN DEL SISTEMA',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.3,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Reportes y estadísticas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Consulta los resultados y la actividad de PetCare.',
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
                    Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 43,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              tituloSeccion(
                'Indicadores disponibles',
                'Resumen de los datos actuales del sistema.',
              ),
              const SizedBox(height: 14),
              tarjetaEstadistica(
                'Usuarios registrados',
                usuarios.length,
                Icons.people_alt_rounded,
                verde,
              ),
              const SizedBox(height: 10),
              tarjetaEstadistica(
                'Mascotas registradas',
                totalMascotas,
                Icons.pets_rounded,
                Colors.teal,
              ),
              const SizedBox(height: 10),
              tarjetaEstadistica(
                'Reservas registradas',
                totalReservas,
                Icons.calendar_month_rounded,
                Colors.deepOrange,
              ),
              const SizedBox(height: 10),
              tarjetaEstadistica(
                'Reservas atendidas',
                reservasAtendidas,
                Icons.medical_information_rounded,
                Colors.indigo,
              ),
              const SizedBox(height: 25),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () {
                    abrirPantalla(const ReportesAdminScreen());
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8EEE9)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, color: verde, size: 32),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Abrir reportes completos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF26372C),
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Ver gráficos y estadísticas detalladas.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: verde,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // TARJETAS GENERALES
  // --------------------------------------------------

  Widget tarjetaAcceso({
    required String titulo,
    required String descripcion,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icono, color: verde, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF26372C),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
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
}
