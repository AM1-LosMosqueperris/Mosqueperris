import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare_santa_cruz/utils/validadores.dart';

class ConsultasScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const ConsultasScreen({super.key, this.onOpenMenu});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _mensaje = TextEditingController();

  bool _enviando = false;
  List<Map<String, dynamic>> _misConsultas = [];
  bool _cargandoConsultas = true;

  /// Tipo de consulta: 'Administrativa' o 'Veterinaria'.
  String _tipoSeleccionado = 'Administrativa';

  /// Id de la mascota asociada (solo para consultas veterinarias).
  String? _mascotaSeleccionadaId;

  List<Map<String, dynamic>> _misMascotas = [];

  RealtimeChannel? _canalConsultas;

  @override
  void initState() {
    super.initState();

    _cargarMisConsultas();
    _cargarMascotas();
    _escucharMisConsultas();
  }

  Future<void> _cargarMascotas() async {
    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) return;

    try {
      final datos = await Supabase.instance.client
          .from('mascotas')
          .select('id, nombre')
          .eq('usuario_id', usuario.id)
          .order('nombre');

      if (!mounted) return;

      setState(() {
        _misMascotas = List<Map<String, dynamic>>.from(datos);
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR MASCOTAS PARA CONSULTA: $e');
    }
  }

  Future<void> _cargarMisConsultas() async {
    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) return;

    try {
      final datos = await Supabase.instance.client
          .from('consultas')
          .select()
          .eq('usuario_id', usuario.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _misConsultas = List<Map<String, dynamic>>.from(datos);
        _cargandoConsultas = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR MIS CONSULTAS: $e');

      if (!mounted) return;

      setState(() {
        _cargandoConsultas = false;
      });
    }
  }

  void _escucharMisConsultas() {
    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) return;

    _canalConsultas = Supabase.instance.client
        .channel('consultas-cliente-${usuario.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'consultas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuario.id,
          ),
          callback: (payload) {
            _cargarMisConsultas();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _mensaje.dispose();
    _canalConsultas?.unsubscribe();
    super.dispose();
  }

  Future<void> _enviarConsulta() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
    });

    try {
      final usuario = Supabase.instance.client.auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          _enviando = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Inicia sesión'),
            content: const Text(
              'Para enviar una consulta necesitas iniciar sesión '
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

      final datos = <String, dynamic>{
        'usuario_id': usuario.id,
        'nombre': _nombre.text.trim(),
        'telefono': _telefono.text.trim(),
        'mensaje': _mensaje.text.trim(),
        'tipo': _tipoSeleccionado,
      };

      final mascotaId = int.tryParse(_mascotaSeleccionadaId ?? '');

      if (mascotaId != null) {
        datos['mascota_id'] = mascotaId;
      }

      await Supabase.instance.client.from('consultas').insert(datos);
      await _cargarMisConsultas();

      if (!mounted) return;

      _nombre.clear();
      _telefono.clear();
      _mensaje.clear();

      setState(() {
        _mascotaSeleccionadaId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta enviada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar consulta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Pendiente':
        return Colors.orange.shade800;
      case 'Admitida':
        return Colors.blue.shade700;
      case 'En atención':
        return Colors.deepPurple;
      case 'Atendida':
        return Colors.green.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Pendiente':
        return Icons.schedule_rounded;
      case 'Admitida':
        return Icons.check_circle_outline_rounded;
      case 'En atención':
        return Icons.medical_services_outlined;
      case 'Atendida':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _descripcionEstado(String estado, bool veterinaria) {
    switch (estado) {
      case 'Pendiente':
        return veterinaria
            ? 'Tu consulta está esperando que el administrador la revise.'
            : 'Tu consulta está esperando la respuesta del administrador.';
      case 'Admitida':
        return 'Tu consulta fue admitida y está disponible para que un veterinario la atienda.';
      case 'En atención':
        return 'Un veterinario ya tomó tu consulta y está preparando una respuesta.';
      case 'Atendida':
        return 'Tu consulta ha sido respondida. Puedes revisar la respuesta a continuación.';
      default:
        return 'Estado actual de tu consulta.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Text('Formulario de consulta'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Tienes alguna consulta?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Completa los siguientes datos para contactarnos.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 25),

              DropdownButtonFormField<String>(
                initialValue: _tipoSeleccionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de consulta',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Administrativa',
                    child: Text(
                      'Administrativa (precios, horarios, reservas...)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Veterinaria',
                    child: Text(
                      'Veterinaria (alimentación, vacunas, síntomas...)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (valor) {
                  if (valor == null) return;

                  setState(() {
                    _tipoSeleccionado = valor;

                    if (valor != 'Veterinaria') {
                      _mascotaSeleccionadaId = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 18),

              if (_tipoSeleccionado == 'Veterinaria') ...[
                DropdownButtonFormField<String>(
                  initialValue: _mascotaSeleccionadaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mascota (opcional)',
                    prefixIcon: Icon(Icons.pets_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _misMascotas.map((mascota) {
                    return DropdownMenuItem<String>(
                      value: mascota['id'].toString(),
                      child: Text(
                        mascota['nombre']?.toString() ?? 'Mascota',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setState(() {
                      _mascotaSeleccionadaId = valor;
                    });
                  },
                ),
                const SizedBox(height: 18),
              ],

              TextFormField(
                controller: _nombre,
                validator: Validadores.nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                validator: Validadores.telefono,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Ej. 71234567',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _mensaje,
                maxLines: 4,
                validator: Validadores.mensaje,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _enviarConsulta,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Enviando...' : 'Enviar consulta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'El teléfono debe tener 8 dígitos.',
                  style: TextStyle(color: verde),
                ),
              ),

              const SizedBox(height: 30),

              const Divider(),

              const SizedBox(height: 15),

              const Text(
                'Mis consultas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),

              const SizedBox(height: 15),

              if (_cargandoConsultas)
                const Center(child: CircularProgressIndicator(color: verde))
              else if (_misConsultas.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: verdeClaro,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: verde),
                      SizedBox(height: 10),
                      Text(
                        'Todavía no tienes consultas enviadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: verde),
                      ),
                    ],
                  ),
                )
              else
                ..._misConsultas.map((consulta) {
                  final estado = (consulta['estado'] ?? 'Pendiente').toString();

                  final fecha = DateTime.tryParse(
                    consulta['created_at']?.toString() ?? '',
                  );

                  final fechaTexto = fecha == null
                      ? 'Fecha no disponible'
                      : '${fecha.day.toString().padLeft(2, '0')}/'
                            '${fecha.month.toString().padLeft(2, '0')}/'
                            '${fecha.year}';

                  final tipo = (consulta['tipo'] ?? 'Administrativa')
                      .toString();
                  final veterinaria = tipo == 'Veterinaria';
                  final respuesta = (consulta['respuesta'] ?? '').toString();

                  final colorEstado = _colorEstado(estado);
                  final iconoEstado = _iconoEstado(estado);
                  final descripcionEstado = _descripcionEstado(
                    estado,
                    veterinaria,
                  );

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Consulta enviada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorEstado.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    iconoEstado,
                                    size: 14,
                                    color: colorEstado,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    estado,
                                    style: TextStyle(
                                      color: colorEstado,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Icon(
                              veterinaria
                                  ? Icons.pets_outlined
                                  : Icons.admin_panel_settings_outlined,
                              size: 16,
                              color: veterinaria
                                  ? Colors.teal.shade700
                                  : Colors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              veterinaria
                                  ? 'Consulta veterinaria'
                                  : 'Consulta administrativa',
                              style: TextStyle(
                                color: veterinaria
                                    ? Colors.teal.shade700
                                    : Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          consulta['mensaje']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              fechaTexto,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          descripcionEstado,
                          style: TextStyle(
                            color: colorEstado,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (respuesta.isNotEmpty) ...[
                          const SizedBox(height: 12),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.reply_rounded,
                                      size: 16,
                                      color: Colors.green.shade800,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Respuesta recibida',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  respuesta,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
