import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/features/administrador/screens/gestion_servicios.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_mascotas.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/gestion_reservas_admin.dart';
import 'package:petcare_santa_cruz/features/administrador/screens/reportes_admin.dart';
import 'package:petcare_santa_cruz/features/notificaciones/screens/notificaciones.dart';

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

  RealtimeChannel? _canalNotificaciones;

  int get totalClientes => usuarios.where((u) => u['rol'] == 'cliente').length;

  int get totalVeterinarios =>
      usuarios.where((u) => u['rol'] == 'veterinario').length;

  int get totalAdministradores =>
      usuarios.where((u) => u['rol'] == 'administrador').length;

  bool cargando = true;
  String? error;
  String textoBusqueda = '';

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
    _cargarNotificacionesAdmin();
    _escucharNotificacionesAdmin();
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

  @override
  void dispose() {
    busquedaController.dispose();

    if (_canalNotificaciones != null) {
      supabase.removeChannel(_canalNotificaciones!);
    }

    super.dispose();
  }

  Future<void> cargarUsuarios() async {
    if (!mounted) return;

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final datos = await supabase.rpc('listar_perfiles_admin');

      if (!mounted) return;

      setState(() {
        usuarios = (datos as List)
            .map((usuario) => Map<String, dynamic>.from(usuario as Map))
            .toList();

        cargando = false;
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

  void abrirPantalla(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
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
                  'CONTROL DEL SISTEMA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Bienvenido, administrador',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${usuarios.length} usuarios registrados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 38,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            cantidad.toString(),
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
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget contenidoPrincipal() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        encabezado(),

        const SizedBox(height: 25),

        tituloSeccion(
          'Resumen del sistema',
          'Indicadores generales de PetCare',
        ),

        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
          childAspectRatio: 1.05,
          children: [
            tarjetaEstadistica(
              'Total usuarios',
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
              'Mascotas registradas',
              totalMascotas,
              Icons.pets_rounded,
              Colors.teal,
            ),
            tarjetaEstadistica(
              'Reservas registradas',
              totalReservas,
              Icons.calendar_month_rounded,
              Colors.deepOrange,
            ),
            tarjetaEstadistica(
              'Consultas atendidas',
              reservasAtendidas,
              Icons.medical_information_rounded,
              Colors.indigo,
            ),
          ],
        ),

        const SizedBox(height: 27),

        tituloSeccion(
          'Administración',
          'Gestiona los módulos principales de la aplicación',
        ),

        const SizedBox(height: 14),

        tarjetaAcceso(
          titulo: 'Administrar servicios',
          descripcion: 'Crear, editar, activar o desactivar servicios.',
          icono: Icons.medical_services_rounded,
          onTap: () => abrirPantalla(const GestionServiciosScreen()),
        ),

        tarjetaAcceso(
          titulo: 'Gestión de mascotas',
          descripcion: 'Consultar mascotas, propietarios y detalles.',
          icono: Icons.pets_rounded,
          onTap: () => abrirPantalla(const GestionMascotasScreen()),
        ),

        tarjetaAcceso(
          titulo: 'Gestión de reservas',
          descripcion: 'Consultar reservas, clientes y estados.',
          icono: Icons.calendar_month_rounded,
          onTap: () => abrirPantalla(const GestionReservasAdminScreen()),
        ),

        tarjetaAcceso(
          titulo: 'Reportes del sistema',
          descripcion: 'Visualizar estadísticas y gráficos del sistema.',
          icono: Icons.bar_chart_rounded,
          onTap: () => abrirPantalla(const ReportesAdminScreen()),
        ),

        const SizedBox(height: 16),

        tituloSeccion(
          'Gestión de usuarios',
          'Consulta las cuentas y administra sus permisos',
        ),

        const SizedBox(height: 14),

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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

        const SizedBox(height: 12),

        if (usuariosFiltrados.isEmpty)
          mensajeSinUsuarios()
        else
          ...usuariosFiltrados.map(tarjetaUsuario),
      ],
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
          'Panel administrador',
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

              _cargarNotificacionesAdmin();
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
            onPressed: cargarUsuarios,
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
        onRefresh: cargarUsuarios,
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
                      onPressed: cargarUsuarios,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : contenidoPrincipal(),
      ),
    );
  }
}
