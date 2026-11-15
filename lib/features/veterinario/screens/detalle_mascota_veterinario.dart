import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetalleMascotaVeterinarioScreen extends StatefulWidget {
  final Map<String, dynamic> mascota;

  const DetalleMascotaVeterinarioScreen({super.key, required this.mascota});

  @override
  State<DetalleMascotaVeterinarioScreen> createState() =>
      _DetalleMascotaVeterinarioScreenState();
}

class _DetalleMascotaVeterinarioScreenState
    extends State<DetalleMascotaVeterinarioScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final supabase = Supabase.instance.client;

  final formKey = GlobalKey<FormState>();
  final descripcionController = TextEditingController();
  final diagnosticoController = TextEditingController();
  final tratamientoController = TextEditingController();
  final vacunaController = TextEditingController();
  final observacionesController = TextEditingController();

  List<Map<String, dynamic>> historial = [];

  String tipoSeleccionado = 'Consulta';
  bool cargando = true;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  @override
  void dispose() {
    descripcionController.dispose();
    diagnosticoController.dispose();
    tratamientoController.dispose();
    vacunaController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  Future<void> cargarHistorial() async {
    setState(() {
      cargando = true;
    });

    try {
      final datos = await supabase
          .from('historial_medico')
          .select()
          .eq('mascota_id', widget.mascota['id'])
          .order('fecha', ascending: false);

      if (!mounted) return;

      setState(() {
        historial = List<Map<String, dynamic>>.from(datos);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      mensaje('No se pudo cargar el historial médico.');
    }
  }

  Future<void> registrarAtencion() async {
    if (!formKey.currentState!.validate()) return;

    final usuario = supabase.auth.currentUser;

    if (usuario == null) {
      mensaje('No hay una sesión activa.');
      return;
    }

    setState(() {
      guardando = true;
    });

    try {
      final perfil = await supabase
          .from('perfiles')
          .select('nombre')
          .eq('id', usuario.id)
          .single();

      await supabase.from('historial_medico').insert({
        'usuario_id': widget.mascota['usuario_id'],
        'mascota_id': widget.mascota['id'],
        'veterinario_id': usuario.id,
        'fecha': DateTime.now().toIso8601String().split('T').first,
        'tipo': tipoSeleccionado,
        'descripcion': descripcionController.text.trim(),
        'diagnostico': diagnosticoController.text.trim(),
        'tratamiento': tratamientoController.text.trim(),
        'vacuna': vacunaController.text.trim(),
        'observaciones': observacionesController.text.trim(),
        'veterinario': perfil['nombre'] ?? 'Veterinario',
      });

      if (!mounted) return;

      descripcionController.clear();
      diagnosticoController.clear();
      tratamientoController.clear();
      vacunaController.clear();
      observacionesController.clear();

      setState(() {
        tipoSeleccionado = 'Consulta';
      });

      mensaje('Atención médica registrada correctamente.');

      await cargarHistorial();
    } catch (e) {
      if (!mounted) return;
      mensaje('No se pudo registrar la atención médica: $e');
    } finally {
      if (mounted) {
        setState(() {
          guardando = false;
        });
      }
    }
  }

  void mensaje(String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto), backgroundColor: verde));
  }

  Widget campo({
    required String titulo,
    required TextEditingController controller,
    bool obligatorio = false,
    int maxLineas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLineas,
        decoration: InputDecoration(
          labelText: titulo,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: obligatorio
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Este campo es obligatorio';
                }
                return null;
              }
            : null,
      ),
    );
  }

  String fechaLegible(dynamic fecha) {
    if (fecha == null) return 'Sin fecha';

    try {
      final partes = fecha.toString().split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return fecha.toString();
    } catch (_) {
      return fecha.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Detalle de mascota'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: verdeClaro,
                        child: Icon(Icons.pets, color: verde, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          mascota['nombre']?.toString() ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  dato('Especie', mascota['especie']),
                  dato('Raza', mascota['raza']),
                  dato('Sexo', mascota['sexo']),
                  dato('Fecha de nacimiento', mascota['fecha_nacimiento']),
                  dato(
                    'Peso',
                    mascota['peso'] == null ? null : '${mascota['peso']} kg',
                  ),
                  dato('Propietario', mascota['propietario']),
                  if (mascota['observaciones'] != null)
                    dato('Observaciones', mascota['observaciones']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          const Text(
            'Registrar nueva atención',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            color: verdeClaro,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: tipoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de atención',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                            'Consulta',
                            'Vacunación',
                            'Control',
                            'Emergencia',
                            'Otro',
                          ].map((tipo) {
                            return DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            tipoSeleccionado = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    campo(
                      titulo: 'Descripción de la atención',
                      controller: descripcionController,
                      obligatorio: true,
                      maxLineas: 3,
                    ),
                    campo(
                      titulo: 'Diagnóstico',
                      controller: diagnosticoController,
                      maxLineas: 2,
                    ),
                    campo(
                      titulo: 'Tratamiento',
                      controller: tratamientoController,
                      maxLineas: 2,
                    ),
                    campo(titulo: 'Vacuna', controller: vacunaController),
                    campo(
                      titulo: 'Observaciones adicionales',
                      controller: observacionesController,
                      maxLineas: 3,
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: guardando ? null : registrarAtencion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verde,
                          foregroundColor: Colors.white,
                        ),
                        icon: guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          guardando
                              ? 'Guardando...'
                              : 'Guardar atención médica',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Historial médico',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 12),

          if (cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: CircularProgressIndicator(color: verde),
              ),
            )
          else if (historial.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Center(
                  child: Text(
                    'Esta mascota todavía no tiene atenciones médicas.',
                  ),
                ),
              ),
            )
          else
            ...historial.map((registro) {
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services_outlined,
                            color: verde,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              registro['tipo']?.toString() ?? 'Atención',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: verde,
                              ),
                            ),
                          ),
                          Text(
                            fechaLegible(registro['fecha']),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      dato('Descripción', registro['descripcion']),
                      dato('Diagnóstico', registro['diagnostico']),
                      dato('Tratamiento', registro['tratamiento']),
                      dato('Vacuna', registro['vacuna']),
                      dato('Observaciones', registro['observaciones']),
                      dato('Veterinario', registro['veterinario']),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget dato(String titulo, dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$titulo: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: valor.toString()),
          ],
        ),
      ),
    );
  }
}
