import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionMascotasScreen extends StatefulWidget {
  const GestionMascotasScreen({super.key});

  @override
  State<GestionMascotasScreen> createState() => _GestionMascotasScreenState();
}

class _GestionMascotasScreenState extends State<GestionMascotasScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final supabase = Supabase.instance.client;
  final TextEditingController busquedaController = TextEditingController();

  List<Map<String, dynamic>> mascotas = [];
  RealtimeChannel? _canalMascotas;

  bool cargando = true;
  String? error;
  String textoBusqueda = '';
  int contarEspecie(String especie) {
    return mascotas.where((mascota) {
      return mascota['especie']?.toString().toLowerCase().trim() ==
          especie.toLowerCase();
    }).length;
  }

  int get otrasEspecies {
    return mascotas.where((mascota) {
      final especie = mascota['especie']?.toString().toLowerCase().trim() ?? '';
      return especie != 'perro' && especie != 'gato';
    }).length;
  }

  List<Map<String, dynamic>> get mascotasFiltradas {
    if (textoBusqueda.trim().isEmpty) return mascotas;

    final busqueda = textoBusqueda.toLowerCase().trim();

    return mascotas.where((mascota) {
      final nombre = (mascota['nombre'] ?? '').toString().toLowerCase();
      final especie = (mascota['especie'] ?? '').toString().toLowerCase();
      final raza = (mascota['raza'] ?? '').toString().toLowerCase();
      final propietario =
          (mascota['nombre_propietario'] ?? mascota['propietario'] ?? '')
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
    escucharCambios();
  }

  void escucharCambios() {
    _canalMascotas = supabase
        .channel('mascotas-administrador')
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

  @override
  void dispose() {
    if (_canalMascotas != null) {
      supabase.removeChannel(_canalMascotas!);
    }

    busquedaController.dispose();
    super.dispose();
  }

  Future<void> cargarMascotas({bool mostrarCarga = true}) async {
    if (mounted && mostrarCarga) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final datos = await supabase.rpc('listar_mascotas_admin');

      if (!mounted) return;

      setState(() {
        mascotas = (datos as List)
            .map((mascota) => Map<String, dynamic>.from(mascota as Map))
            .toList();

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

  String textoDato(dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) {
      return 'No registrado';
    }
    return valor.toString();
  }

  Widget tarjetaIndicador({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 25),
            const SizedBox(height: 7),
            Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaMascota(Map<String, dynamic> mascota) {
    final nombre = textoDato(mascota['nombre']);
    final especie = textoDato(mascota['especie']);
    final raza = textoDato(mascota['raza']);
    final propietario = textoDato(
      mascota['nombre_propietario'] ?? mascota['propietario'],
    );

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          backgroundColor: verdeClaro,
          child: Icon(Icons.pets, color: verde, size: 26),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, color: verde),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Especie: $especie'),
              Text('Raza: $raza'),
              Text('Propietario: $propietario'),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 17, color: verde),
        onTap: () {
          mostrarDetalles(mascota);
        },
      ),
    );
  }

  void mostrarDetalles(Map<String, dynamic> mascota) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            textoDato(mascota['nombre']),
            style: const TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                datoDetalle('Especie', mascota['especie']),
                datoDetalle('Raza', mascota['raza']),
                datoDetalle('Sexo', mascota['sexo']),
                datoDetalle('Fecha de nacimiento', mascota['fecha_nacimiento']),
                datoDetalle('Peso', mascota['peso']),
                datoDetalle(
                  'Propietario',
                  mascota['nombre_propietario'] ?? mascota['propietario'],
                ),
                datoDetalle('Observaciones', mascota['observaciones']),
                datoDetalle('ID de mascota', mascota['id']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar', style: TextStyle(color: verde)),
            ),
          ],
        );
      },
    );
  }

  Widget datoDetalle(String titulo, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, color: verde),
          ),
          const SizedBox(height: 3),
          Text(textoDato(valor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Text('Gestión de mascotas'),
        actions: [
          IconButton(
            onPressed: cargarMascotas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: cargarMascotas,
        child: cargando
            ? const Center(child: CircularProgressIndicator(color: verde))
            : error != null
            ? ListView(
                children: [
                  const SizedBox(height: 150),
                  Center(child: Text(error!)),
                  Center(
                    child: TextButton(
                      onPressed: cargarMascotas,
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: verde,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pets, color: Colors.white, size: 38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mascotas registradas',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${mascotas.length} mascotas en el sistema',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Total',
                        cantidad: mascotas.length,
                        icono: Icons.pets,
                        color: verde,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Perros',
                        cantidad: contarEspecie('perro'),
                        icono: Icons.pets,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      tarjetaIndicador(
                        titulo: 'Gatos',
                        cantidad: contarEspecie('gato'),
                        icono: Icons.pets,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      tarjetaIndicador(
                        titulo: 'Otras especies',
                        cantidad: otrasEspecies,
                        icono: Icons.cruelty_free,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: busquedaController,
                    onChanged: (valor) {
                      setState(() {
                        textoBusqueda = valor;
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por nombre, especie, raza o propietario...',
                      prefixIcon: const Icon(Icons.search, color: verde),
                      suffixIcon: textoBusqueda.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                busquedaController.clear();
                                setState(() {
                                  textoBusqueda = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (mascotasFiltradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(25),
                      child: Center(child: Text('No se encontraron mascotas.')),
                    ),
                  ...mascotasFiltradas.map(tarjetaMascota),
                ],
              ),
      ),
    );
  }
}
