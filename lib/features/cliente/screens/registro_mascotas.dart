import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroMascotasScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const RegistroMascotasScreen({super.key, this.onOpenMenu});

  @override
  State<RegistroMascotasScreen> createState() => _RegistroMascotasScreenState();
}

class _RegistroMascotasScreenState extends State<RegistroMascotasScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

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

  Future<void> cargarMascotas() async {
    final usuario = db.auth.currentUser;

    if (usuario == null) {
      if (!mounted) return;
      setState(() {
        mascotas = [];
        cargando = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        cargando = true;
      });
    }

    try {
      final datos = await db
          .from('mascotas')
          .select()
          .eq('usuario_id', usuario.id)
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

  Future<void> registrarMascota() async {
    if (enviando) return;

    if (!_formKey.currentState!.validate()) return;

    final edad = int.parse(edadController.text.trim());

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
          builder: (dialogContext) => AlertDialog(
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
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
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
          content: Text('¡Mascota registrada correctamente!'),
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

  int? calcularEdad(dynamic fechaNacimiento) {
    if (fechaNacimiento == null) return null;

    final fecha = DateTime.tryParse(fechaNacimiento.toString());
    if (fecha == null) return null;

    final hoy = DateTime.now();
    var edad = hoy.year - fecha.year;

    if (hoy.month < fecha.month ||
        (hoy.month == fecha.month && hoy.day < fecha.day)) {
      edad--;
    }

    return edad < 0 ? 0 : edad;
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
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Row(
          children: [
            Icon(Icons.pets, size: 24),
            SizedBox(width: 10),
            Text(
              'PetCare Santa Cruz',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar mascotas',
            onPressed: cargando ? null : cargarMascotas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: verde,
        onRefresh: cargarMascotas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(),
                  const SizedBox(height: 25),
                  _tituloSeccion(Icons.edit_note, 'Datos de tu mascota'),
                  const SizedBox(height: 14),
                  _formulario(),
                  const SizedBox(height: 28),
                  _seccionMascotas(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17623F), Color(0xFF248454)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: verde.withValues(alpha: 0.18),
            blurRadius: 16,
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
                  'Registro de mascotas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Registra a tu compañero y mantén '
                  'su información organizada para cuidar '
                  'mejor de su salud.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cada mascota es especial',
                    style: TextStyle(
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
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 42),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(IconData icono, String titulo) {
    return Row(
      children: [
        Icon(icono, color: verde, size: 23),
        const SizedBox(width: 9),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF26352B),
          ),
        ),
      ],
    );
  }

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _campoTexto(
              controller: nombreController,
              etiqueta: 'Nombre de la mascota',
              icono: Icons.pets_outlined,
              mensaje: 'Ingresa el nombre de la mascota',
            ),
            const SizedBox(height: 16),
            _campoSelector(
              etiqueta: 'Especie',
              icono: Icons.category_outlined,
              valor: especieSeleccionada,
              opciones: ['Perro', 'Gato', 'Otro'],
              onChanged: (value) {
                setState(() {
                  especieSeleccionada = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _campoSelector(
              etiqueta: 'Sexo',
              icono: Icons.wc_outlined,
              valor: sexoSeleccionado,
              opciones: ['Macho', 'Hembra'],
              onChanged: (value) {
                setState(() {
                  sexoSeleccionado = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: edadController,
              keyboardType: TextInputType.number,
              decoration: _decoracion(
                'Edad en años',
                Icons.cake_outlined,
                hint: 'Ej. 2',
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
            _campoTexto(
              controller: razaController,
              etiqueta: 'Raza',
              icono: Icons.info_outline,
              mensaje: 'Ingresa la raza',
            ),
            const SizedBox(height: 16),
            _campoTexto(
              controller: propietarioController,
              etiqueta: 'Nombre del propietario',
              icono: Icons.person_outline,
              mensaje: 'Ingresa el nombre del propietario',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 53,
              child: ElevatedButton.icon(
                onPressed: enviando ? null : registrarMascota,
                icon: enviando
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  enviando ? 'Guardando...' : 'Registrar mascota',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta, IconData icono, {String? hint}) {
    return InputDecoration(
      labelText: etiqueta,
      hintText: hint,
      prefixIcon: Icon(icono, color: verde),
      filled: true,
      fillColor: const Color(0xFFFAFCFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE1E9E2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE1E9E2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: verde, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    required String mensaje,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decoracion(etiqueta, icono),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return mensaje;
        }
        return null;
      },
    );
  }

  Widget _campoSelector({
    required String etiqueta,
    required IconData icono,
    required String valor,
    required List<String> opciones,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      decoration: _decoracion(etiqueta, icono),
      items: opciones.map((opcion) {
        return DropdownMenuItem(value: opcion, child: Text(opcion));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _seccionMascotas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _tituloSeccion(Icons.pets_outlined, 'Mis mascotas'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${mascotas.length} registradas',
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: verde),
            ),
          )
        else if (mascotas.isEmpty)
          _estadoVacio()
        else
          ...mascotas.map(_tarjetaMascota),
      ],
    );
  }

  Widget _tarjetaMascota(Map<String, dynamic> mascota) {
    final edad = calcularEdad(mascota['fecha_nacimiento']);

    final especie = mascota['especie']?.toString() ?? 'Sin especie';
    final sexo = mascota['sexo']?.toString() ?? 'Sin especificar';
    final raza = mascota['raza']?.toString() ?? 'Sin raza';
    final propietario = mascota['propietario']?.toString() ?? 'No especificado';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: verdeClaro,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              especie.toLowerCase() == 'gato'
                  ? Icons.pets
                  : Icons.pets_outlined,
              color: verde,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mascota['nombre']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF26352B),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$especie • $sexo',
                  style: const TextStyle(
                    color: verde,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                _datoMascota(Icons.info_outline, 'Raza: $raza'),
                const SizedBox(height: 5),
                _datoMascota(
                  Icons.cake_outlined,
                  'Edad: ${edad == null ? 'No especificada' : '$edad años'}',
                ),
                const SizedBox(height: 5),
                _datoMascota(Icons.person_outline, 'Propietario: $propietario'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoMascota(IconData icono, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: Color(0xFF78827A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _estadoVacio() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: const Column(
        children: [
          Icon(Icons.pets_outlined, size: 43, color: verde),
          SizedBox(height: 12),
          Text(
            'Todavía no tienes mascotas registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF526057),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Completa el formulario para agregar tu primera mascota.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
