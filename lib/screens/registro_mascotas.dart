import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroMascotasScreen extends StatefulWidget {
  const RegistroMascotasScreen({super.key});

  @override
  State<RegistroMascotasScreen> createState() => _RegistroMascotasScreenState();
}

class _RegistroMascotasScreenState extends State<RegistroMascotasScreen> {
  final _formKey = GlobalKey<FormState>();
  final db = Supabase.instance.client;

  final nombreController = TextEditingController();
  final edadController = TextEditingController();
  final razaController = TextEditingController();
  final propietarioController = TextEditingController();

  String especieSeleccionada = 'Perro';
  String sexoSeleccionado = 'Macho';

  List<Map<String, dynamic>> mascotas = [];

  bool cargando = true;
  bool enviando = false;

  @override
  void initState() {
    super.initState();
    cargarMascotas();
  }

  // Consultar mascotas guardadas en Supabase
  Future<void> cargarMascotas() async {
    try {
      final datos = await db
          .from('mascotas')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        mascotas = List<Map<String, dynamic>>.from(datos);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las mascotas.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Registrar mascota en Supabase
  Future<void> registrarMascota() async {
    if (enviando) return;

    if (!_formKey.currentState!.validate()) return;

    final edad = int.parse(edadController.text.trim());

    // Convertir la edad en una fecha aproximada de nacimiento
    final fechaNacimiento = DateTime(
      DateTime.now().year - edad,
      DateTime.now().month,
      DateTime.now().day,
    );

    setState(() {
      enviando = true;
    });

    try {
      final usuario = db.auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          enviando = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Inicia sesión'),
            content: const Text(
              'Para registrar una mascota necesitas iniciar sesión '
              'o crear una cuenta en PetCare.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF17623F),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );

        return;
      }

      await db.from('mascotas').insert({
        'usuario_id': usuario.id,
        'nombre': nombreController.text.trim(),
        'especie': especieSeleccionada,
        'raza': razaController.text.trim(),
        'fecha_nacimiento':
            '${fechaNacimiento.year.toString().padLeft(4, '0')}-'
            '${fechaNacimiento.month.toString().padLeft(2, '0')}-'
            '${fechaNacimiento.day.toString().padLeft(2, '0')}',
        'sexo': sexoSeleccionado,
        'propietario': propietarioController.text.trim(),
      });

      if (!mounted) return;

      nombreController.clear();
      edadController.clear();
      razaController.clear();
      propietarioController.clear();

      setState(() {
        especieSeleccionada = 'Perro';
        sexoSeleccionado = 'Macho';
      });

      await cargarMascotas();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Mascota guardada correctamente en Supabase!'),
          backgroundColor: Color(0xFF269B79),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la mascota: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    edadController.dispose();
    razaController.dispose();
    propietarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PetCare Santa Cruz',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar mascotas',
            onPressed: cargarMascotas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pets, size: 65, color: Color(0xFF269B79)),
                const SizedBox(height: 10),
                const Text(
                  'Registro de mascotas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra a tu compañero para cuidar mejor de su salud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),

                Card(
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la mascota',
                              prefixIcon: Icon(Icons.pets),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa el nombre de la mascota';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            initialValue: especieSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Especie',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(),
                            ),
                            items: ['Perro', 'Gato', 'Otro'].map((especie) {
                              return DropdownMenuItem(
                                value: especie,
                                child: Text(especie),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  especieSeleccionada = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            initialValue: sexoSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Sexo',
                              prefixIcon: Icon(Icons.wc),
                              border: OutlineInputBorder(),
                            ),
                            items: ['Macho', 'Hembra'].map((sexo) {
                              return DropdownMenuItem(
                                value: sexo,
                                child: Text(sexo),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  sexoSeleccionado = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: edadController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Edad en años',
                              hintText: 'Ej. 2',
                              prefixIcon: Icon(Icons.cake),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa la edad';
                              }

                              final edad = int.tryParse(value.trim());

                              if (edad == null || edad < 0 || edad > 40) {
                                return 'Ingresa una edad entre 0 y 40 años';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: razaController,
                            decoration: const InputDecoration(
                              labelText: 'Raza',
                              prefixIcon: Icon(Icons.info_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa la raza';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: propietarioController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del propietario',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa el nombre del propietario';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: enviando ? null : registrarMascota,
                              icon: enviando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                enviando ? 'Guardando...' : 'Registrar mascota',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF269B79),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Mascotas registradas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (mascotas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Todavía no hay mascotas registradas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...mascotas.map((mascota) {
                    final fecha = mascota['fecha_nacimiento'] != null
                        ? DateTime.tryParse(
                            mascota['fecha_nacimiento'].toString(),
                          )
                        : null;

                    final edad = fecha == null
                        ? 'No especificada'
                        : '${DateTime.now().year - fecha.year} años';

                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2EC),
                          child: Icon(Icons.pets, color: Color(0xFF269B79)),
                        ),
                        title: Text(
                          mascota['nombre']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${mascota['especie']} • '
                          '${mascota['sexo'] ?? 'Sin especificar'} • '
                          '${mascota['raza'] ?? 'Sin raza'}\n'
                          'Edad: $edad\n'
                          'Propietario: '
                          '${mascota['propietario'] ?? 'No especificado'}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
