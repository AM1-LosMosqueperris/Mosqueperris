import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControlVacunasScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const ControlVacunasScreen({super.key, this.onOpenMenu});

  @override
  State<ControlVacunasScreen> createState() => _ControlVacunasScreenState();
}

class _ControlVacunasScreenState extends State<ControlVacunasScreen> {
  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? error;
  int? mascotaSeleccionada;

  List<Map<String, dynamic>> mascotas = [];
  List<Map<String, dynamic>> vacunas = [];

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      setState(() {
        cargando = false;
        error = 'Debes iniciar sesión para consultar tus vacunas.';
      });
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final resultados = await Future.wait([
        supabase
            .from('mascotas')
            .select('id, nombre')
            .eq('usuario_id', usuario.id),
        supabase
            .from('historial_medico')
            .select('id, mascota_id, fecha, vacuna, veterinario, observaciones')
            .eq('usuario_id', usuario.id)
            .not('vacuna', 'is', null)
            .neq('vacuna', ''),
      ]);

      final listaMascotas = List<Map<String, dynamic>>.from(resultados[0]);

      final listaVacunas = List<Map<String, dynamic>>.from(resultados[1]);

      listaVacunas.sort((a, b) {
        final fechaA = DateTime.tryParse(a['fecha']?.toString() ?? '');
        final fechaB = DateTime.tryParse(b['fecha']?.toString() ?? '');

        if (fechaA == null || fechaB == null) return 0;
        return fechaB.compareTo(fechaA);
      });

      if (!mounted) return;

      setState(() {
        mascotas = listaMascotas;
        vacunas = listaVacunas;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar vacunas: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las vacunas.';
      });
    }
  }

  String formatoFecha(dynamic valor) {
    if (valor == null) return 'Fecha no disponible';

    final fecha = DateTime.tryParse(valor.toString());

    if (fecha == null) return 'Fecha no disponible';

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String nombreMascota(dynamic mascotaId) {
    final mascota = mascotas.where(
      (m) => m['id'].toString() == mascotaId.toString(),
    );

    if (mascota.isEmpty) return 'Mascota';

    return mascota.first['nombre']?.toString() ?? 'Mascota';
  }

  List<Map<String, dynamic>> get vacunasFiltradas {
    if (mascotaSeleccionada == null) return vacunas;

    return vacunas.where((vacuna) {
      return vacuna['mascota_id'].toString() == mascotaSeleccionada.toString();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lista = vacunasFiltradas;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Text('Control de vacunas'),
        actions: [
          IconButton(
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [verde, Color(0xFF278653)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.vaccines, color: Colors.white, size: 38),
                    SizedBox(height: 12),
                    Text(
                      'Control de vacunas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Consulta las vacunas aplicadas a tus mascotas '
                      'y mantén actualizado su historial.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Filtrar por mascota',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<int?>(
                initialValue: mascotaSeleccionada,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                  labelText: 'Seleccionar mascota',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todas las mascotas'),
                  ),
                  ...mascotas.map((mascota) {
                    return DropdownMenuItem<int?>(
                      value: mascota['id'] as int,
                      child: Text(mascota['nombre'].toString()),
                    );
                  }),
                ],
                onChanged: (valor) {
                  setState(() {
                    mascotaSeleccionada = valor;
                  });
                },
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vacunas registradas',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${lista.length} registros',
                    style: const TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (cargando)
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Center(child: CircularProgressIndicator(color: verde)),
                )
              else if (error != null)
                _mensaje(Icons.error_outline, error!, Colors.red)
              else if (mascotas.isEmpty)
                _mensaje(
                  Icons.pets,
                  'Todavía no tienes mascotas registradas.',
                  verde,
                )
              else if (lista.isEmpty)
                _mensaje(
                  Icons.vaccines,
                  'Aún no hay vacunas registradas para esta selección.',
                  verde,
                )
              else
                ...lista.map((vacuna) {
                  return _tarjetaVacuna(vacuna);
                }),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: verde),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Las vacunas aplicadas son registradas por '
                        'el veterinario. Si necesitas actualizar '
                        'la información, comunícate con la clínica.',
                        style: TextStyle(color: verde, fontSize: 13),
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

  Widget _tarjetaVacuna(Map<String, dynamic> vacuna) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: verdeClaro,
              child: Icon(Icons.vaccines, color: verde),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vacuna['vacuna']?.toString() ?? 'Vacuna',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text('Mascota: ${nombreMascota(vacuna['mascota_id'])}'),
                  const SizedBox(height: 5),
                  Text('Aplicada: ${formatoFecha(vacuna['fecha'])}'),
                  if (vacuna['veterinario'] != null &&
                      vacuna['veterinario'].toString().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('Veterinario: ${vacuna['veterinario']}'),
                  ],
                  if (vacuna['observaciones'] != null &&
                      vacuna['observaciones'].toString().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('Observaciones: ${vacuna['observaciones']}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensaje(IconData icono, String mensaje, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Center(
          child: Column(
            children: [
              Icon(icono, size: 42, color: color),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
