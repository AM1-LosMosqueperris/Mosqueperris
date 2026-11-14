import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/config.dart';

import 'screens/inicio.dart';
import 'screens/registro_mascotas.dart';
import 'screens/servicios.dart';
import 'screens/reservas_citas.dart';
import 'screens/control_vacunas.dart';
import 'screens/historial.dart';
import 'screens/tienda.dart';
import 'screens/contacto.dart';
import 'screens/bienvenida.dart';
import 'screens/consultas.dart';
import 'screens/login.dart';
import 'screens/nueva_password.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    final respuesta = await Supabase.instance.client
        .from('servicios')
        .select('id')
        .limit(1);

    debugPrint('CONEXION SUPABASE CORRECTA: $respuesta');
  } catch (e) {
    debugPrint('ERROR DE CONEXION SUPABASE: $e');
  }

  runApp(const PetCareApp());
}

class PetCareApp extends StatefulWidget {
  const PetCareApp({super.key});

  @override
  State<PetCareApp> createState() => _PetCareAppState();
}

class _PetCareAppState extends State<PetCareApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final dynamic _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        debugPrint('EVENTO SUPABASE: ${data.event}');

        if (data.event == AuthChangeEvent.passwordRecovery) {
          debugPrint('RECUPERACION DETECTADA');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = _navigatorKey.currentState;

            if (navigator != null && navigator.mounted) {
              debugPrint('ABRIENDO PANTALLA NUEVA PASSWORD');
              navigator.pushNamed('/nueva-password');
            } else {
              debugPrint('ERROR: NAVIGATOR NO DISPONIBLE');
            }
          });
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Error en autenticación: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PetCare Santa Cruz',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF17623F)),
        scaffoldBackgroundColor: const Color(0xFFF7FAF6),
      ),
      home: const BienvenidaScreen(),
      routes: {
        '/app': (context) => const PetCareNavigation(initialIndex: 2),
        '/login': (context) => const LoginScreen(),
        '/nueva-password': (context) => const NuevaPasswordScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      },
    );
  }
}

class PetCareNavigation extends StatefulWidget {
  final int initialIndex;

  const PetCareNavigation({super.key, this.initialIndex = 0});

  @override
  State<PetCareNavigation> createState() => _PetCareNavigationState();
}

class _PetCareNavigationState extends State<PetCareNavigation> {
  int selectedIndex = 0;

  String? servicioPendiente;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  List<Widget> get screens => [
    InicioScreen(onNavigate: cambiarPantalla),
    const RegistroMascotasScreen(),
    ServiciosScreen(onSolicitarServicio: solicitarServicio),
    ReservasCitasScreen(servicioInicial: servicioPendiente),
    const ControlVacunasScreen(),
    const HistorialScreen(),
    const TiendaScreen(),
    const ContactoScreen(),
    const ConsultasScreen(),
  ];

  void cambiarPantalla(int index) {
    setState(() {
      selectedIndex = index;

      if (index == 3) {
        servicioPendiente = null;
      }
    });
  }

  void solicitarServicio(String nombreServicio) {
    setState(() {
      servicioPendiente = nombreServicio;
      selectedIndex = 3;
    });
  }

  void seleccionarDesdeMenu(int index) {
    Navigator.pop(context);
    cambiarPantalla(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 25),
              color: const Color(0xFF17623F),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.pets, size: 35, color: Color(0xFF17623F)),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'PetCare Santa Cruz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Cuidamos a quienes más quieres',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _opcionMenu(Icons.home_outlined, 'Inicio', 0),
                  _opcionMenu(Icons.pets_outlined, 'Mis mascotas', 1),
                  _opcionMenu(Icons.medical_services_outlined, 'Servicios', 2),
                  _opcionMenu(
                    Icons.calendar_month_outlined,
                    'Reservar cita',
                    3,
                  ),
                  _opcionMenu(Icons.vaccines_outlined, 'Vacunas', 4),

                  const Divider(),

                  _opcionMenu(Icons.history, 'Historial', 5),
                  _opcionMenu(Icons.store_outlined, 'Tienda', 6),
                  _opcionMenu(Icons.contact_support_outlined, 'Contacto', 7),
                  _opcionMenu(Icons.question_answer_outlined, 'Consultas', 8),
                ],
              ),
            ),

            Column(
              children: [
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();

                    if (!context.mounted) return;

                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'PetCare Santa Cruz © 2026',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      body: IndexedStack(index: selectedIndex, children: screens),

      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.small(
          backgroundColor: const Color(0xFF17623F),
          foregroundColor: Colors.white,
          tooltip: 'Abrir menú',
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
          child: const Icon(Icons.menu),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 5 ? selectedIndex : 0,
        onDestinationSelected: cambiarPantalla,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Mascotas',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.vaccines_outlined),
            selectedIcon: Icon(Icons.vaccines),
            label: 'Vacunas',
          ),
        ],
      ),
    );
  }

  Widget _opcionMenu(IconData icono, String titulo, int index) {
    return ListTile(
      leading: Icon(
        icono,
        color: selectedIndex == index
            ? const Color(0xFF17623F)
            : Colors.black54,
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: selectedIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
          color: selectedIndex == index
              ? const Color(0xFF17623F)
              : Colors.black87,
        ),
      ),
      selected: selectedIndex == index,
      selectedTileColor: const Color(0xFFE8F5ED),
      onTap: () => seleccionarDesdeMenu(index),
    );
  }
}
